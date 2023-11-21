﻿namespace NtdsAudit
{
    using Microsoft.Extensions.CommandLineUtils;
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Globalization;
    using System.IO;
    using System.Linq;
    using System.Reflection;
    using System.Security.Principal;

    /// <summary>
    /// The application entry point class.
    /// </summary>
    internal static class Program
    {
        private static double GetPercentage(int actual, int maximum) => Math.Round(((double)100 / maximum) * actual, 1);


        public class AssocPassHash
        {
            public string hash;
            public string pass;
            public int count;
            public int len;

            public AssocPassHash(string pHash, string pPass, int pLen)
            {
                this.count = 0;
                this.hash = pHash;
                this.pass = pPass;
                this.len = pLen;
            }
        };

        [Conditional("DEBUG")]
        private static void LaunchDebugger()
        {
            if (!Debugger.IsAttached)
            {
                Debugger.Launch();
            }
        }

        private static void Main(string[] args)
        {
            LaunchDebugger();

            var commandLineApplication = new CommandLineApplication
            {
                FullName = "NtdsAudit",
                Description = "A utility for auditing Active Directory",
                ExtendedHelpText = @"
WARNING: Use of the --pwdump option will result in decryption of password hashes using the System Key.
Sensitive information will be stored in memory and on disk. Ensure the pwdump file is handled appropriately.",
            };

            commandLineApplication.VersionOption("-v | --version", Assembly.GetEntryAssembly().GetName().Version.ToString());

            commandLineApplication.HelpOption("-h | --help");

            var ntdsPath = commandLineApplication.Argument("NTDS file", "The path of the NTDS.dit database to be audited, required.", false);
            var systemHivePath = commandLineApplication.Option("-s | --system <file>", "The path of the associated SYSTEM hive, required when using the pwdump option.", CommandOptionType.SingleValue);
            var pwdumpPath = commandLineApplication.Option("-p | --pwdump <file>", "The path to output hashes in pwdump format.", CommandOptionType.SingleValue);
            var usersCsvPath = commandLineApplication.Option("-u | --users-csv <file>", "The path to output user details in CSV format.", CommandOptionType.SingleValue);
            var computersCsvPath = commandLineApplication.Option("-c | --computers-csv <file>", "The path to output computer details in CSV format.", CommandOptionType.SingleValue);
            var includeHistoryHashes = commandLineApplication.Option("--history-hashes", "Include history hashes in the pdwump output.", CommandOptionType.NoValue);
            var dumpReversiblePath = commandLineApplication.Option("--dump-reversible <file>", "The path to output clear text passwords, if reversible encryption is enabled.", CommandOptionType.SingleValue);
            var wordlistPath = commandLineApplication.Option("--wordlist", "The path to a wordlist of weak passwords for basic hash cracking. Warning, using this option is slow, the use of a dedicated password cracker, such as 'john', is recommended instead.", CommandOptionType.SingleValue);
            var ouFilterFilePath = commandLineApplication.Option("--ou-filter-file <file>", "The path to file containing a line separated list of OUs to which to limit user and computer results.", CommandOptionType.SingleValue);
            var baseDate = commandLineApplication.Option("--base-date <yyyyMMdd>", "Specifies a custom date to be used as the base date in statistics. The last modified date of the NTDS file is used by default.", CommandOptionType.SingleValue);
            var debug = commandLineApplication.Option("--debug", "Show debug output.", CommandOptionType.NoValue);
            var potFile = commandLineApplication.Option("--potfile <file>", "The path of hashcat potfile in pwdump format.", CommandOptionType.SingleValue);

            commandLineApplication.OnExecute(() =>
            {
                var argumentsValid = true;
                var showHelp = false;

                if (debug.HasValue())
                {
                    NtdsAudit.ShowDebugOutput = true;
                }

                if (string.IsNullOrWhiteSpace(ntdsPath.Value))
                {
                    ConsoleEx.WriteError($"Missing NTDS file argument.");
                    argumentsValid = false;
                    showHelp = true;
                }
                else if (!File.Exists(ntdsPath.Value))
                {
                    ConsoleEx.WriteError($"NTDS file \"{ntdsPath.Value}\" does not exist.");
                    argumentsValid = false;
                }

                if (pwdumpPath.HasValue() && !systemHivePath.HasValue())
                {
                    ConsoleEx.WriteError($"SYSTEM file argument is required when using the pwdump option.");
                    argumentsValid = false;
                    showHelp = true;
                }
                else if (pwdumpPath.HasValue() && !File.Exists(systemHivePath.Value()))
                {
                    ConsoleEx.WriteError($"SYSTEM file \"{systemHivePath.Value()}\" does not exist.");
                    argumentsValid = false;
                }

                if (pwdumpPath.HasValue() && !string.IsNullOrEmpty(Path.GetDirectoryName(pwdumpPath.Value())) && !Directory.Exists(Path.GetDirectoryName(pwdumpPath.Value())))
                {
                    ConsoleEx.WriteError($"pwdump output directory \"{Path.GetDirectoryName(pwdumpPath.Value())}\" does not exist.");
                    argumentsValid = false;
                }

                if (usersCsvPath.HasValue() && !string.IsNullOrEmpty(Path.GetDirectoryName(usersCsvPath.Value())) && !Directory.Exists(Path.GetDirectoryName(usersCsvPath.Value())))
                {
                    ConsoleEx.WriteError($"Users CSV output directory \"{Path.GetDirectoryName(usersCsvPath.Value())}\" does not exist.");
                    argumentsValid = false;
                }

                if (computersCsvPath.HasValue() && !string.IsNullOrEmpty(Path.GetDirectoryName(computersCsvPath.Value())) && !Directory.Exists(Path.GetDirectoryName(computersCsvPath.Value())))
                {
                    ConsoleEx.WriteError($"Computers CSV output directory \"{Path.GetDirectoryName(computersCsvPath.Value())}\" does not exist.");
                    argumentsValid = false;
                }

                if (dumpReversiblePath.HasValue() && !string.IsNullOrEmpty(Path.GetDirectoryName(dumpReversiblePath.Value())) && !Directory.Exists(Path.GetDirectoryName(dumpReversiblePath.Value())))
                {
                    ConsoleEx.WriteError($"Dump Reversible output directory \"{Path.GetDirectoryName(dumpReversiblePath.Value())}\" does not exist.");
                    argumentsValid = false;
                }

                if (wordlistPath.HasValue() && !File.Exists(wordlistPath.Value()))
                {
                    ConsoleEx.WriteError($"Wordlist file \"{wordlistPath.Value()}\" does not exist.");
                    argumentsValid = false;
                }

                if (ouFilterFilePath.HasValue() && !File.Exists(ouFilterFilePath.Value()))
                {
                    ConsoleEx.WriteError($"OU filter file \"{ouFilterFilePath.Value()}\" does not exist.");
                    argumentsValid = false;
                }

                if (showHelp)
                {
                    commandLineApplication.ShowHelp();
                }

                if (!showHelp && argumentsValid)
                {
                    var ntdsAudit = new NtdsAudit(ntdsPath.Value, pwdumpPath.HasValue(), includeHistoryHashes.HasValue(), systemHivePath.Value(), wordlistPath.Value(), ouFilterFilePath.Value());

                    var baseDateTime = baseDate.HasValue() ? DateTime.ParseExact(baseDate.Value(), "yyyyMMdd", null, DateTimeStyles.AssumeUniversal) : new FileInfo(ntdsPath.Value).LastWriteTimeUtc;

                    PrintConsoleStatistics(ntdsAudit, baseDateTime);

                    if (pwdumpPath.HasValue())
                    {
                        WritePwDumpFile(pwdumpPath.Value(), ntdsAudit, baseDateTime, includeHistoryHashes.HasValue(), wordlistPath.HasValue(), dumpReversiblePath.Value());
                    }

                    if (usersCsvPath.HasValue())
                    {
                        WriteUsersCsvFile(usersCsvPath.Value(), ntdsAudit, baseDateTime, potFile.Value());
                    }

                    if (computersCsvPath.HasValue())
                    {
                        WriteComputersCsvFile(computersCsvPath.Value(), ntdsAudit, baseDateTime);
                    }
                }

                return argumentsValid ? 0 : -1;
            });

            try
            {
                commandLineApplication.Execute(args);
            }
            catch (CommandParsingException ex)
            {
                Console.WriteLine(ex.Message);
            }
        }

        private static void PrintConsoleStatistics(NtdsAudit ntdsAudit, DateTime baseDateTime)
        {
            Console.WriteLine();
            Console.WriteLine($"The base date used for statistics is {baseDateTime}");
            Console.WriteLine();

            foreach (var domain in ntdsAudit.Domains)
            {
                Console.WriteLine($"Account stats for: {domain.Fqdn} ({domain.Sid})");

                var users = ntdsAudit.Users.Where(x => x.DomainSid.Equals(domain.Sid)).ToList();
                var totalUsersCount = users.Count;
                var disabledUsersCount = users.Count(x => x.Disabled);
                var expiredUsersCount = users.Count(x => !x.Disabled && x.Expires.HasValue && x.Expires.Value < baseDateTime);
                var activeUsers = users.Where(x => !x.Disabled && (!x.Expires.HasValue || x.Expires.Value > baseDateTime)).ToList();
                var activeUsersCount = activeUsers.Count;
                var activeUsersUnusedIn1Year = activeUsers.Count(x => x.LastLogon + TimeSpan.FromDays(365) < baseDateTime);
                var activeUsersUnusedIn90Days = activeUsers.Count(x => x.LastLogon + TimeSpan.FromDays(90) < baseDateTime);
                var activeUsersWithPasswordNotRequired = activeUsers.Count(x => x.PasswordNotRequired);
                var activeUsersWithPasswordNeverExpires = activeUsers.Count(x => !x.PasswordNeverExpires);
                var activeUsersPasswordUnchangedIn1Year = activeUsers.Count(x => x.PasswordLastChanged + TimeSpan.FromDays(365) < baseDateTime);
                var activeUsersPasswordUnchangedIn90Days = activeUsers.Count(x => x.PasswordLastChanged + TimeSpan.FromDays(90) < baseDateTime);

                var activeUsersWithAdministratorMembership = activeUsers.Where(x => x.RecursiveGroupSids.Contains(domain.AdministratorsSid)).ToArray();
                var activeUsersWithDomainAdminMembership = activeUsers.Where(x => x.RecursiveGroupSids.Contains(domain.DomainAdminsSid)).ToArray();

                // Unlike Domain Admins and Adminsitrators, Enterprise Admins is not domain local, so include all users.
                var activeUsersWithEnterpriseAdminMembership = ntdsAudit.Users.Where(x => !x.Disabled && (!x.Expires.HasValue || x.Expires.Value > baseDateTime) && x.RecursiveGroupSids.Contains(domain.EnterpriseAdminsSid)).ToArray();

                WriteStatistic("Disabled users", disabledUsersCount, totalUsersCount);
                WriteStatistic("Expired users", expiredUsersCount, totalUsersCount);
                WriteStatistic("Active users unused in 1 year", activeUsersUnusedIn1Year, activeUsersCount);
                WriteStatistic("Active users unused in 90 days", activeUsersUnusedIn90Days, activeUsersCount);
                WriteStatistic("Active users which do not require a password", activeUsersWithPasswordNotRequired, activeUsersCount);
                WriteStatistic("Active users with non-expiring passwords", activeUsersWithPasswordNeverExpires, activeUsersCount);
                WriteStatistic("Active users with password unchanged in 1 year", activeUsersPasswordUnchangedIn1Year, activeUsersCount);
                WriteStatistic("Active users with password unchanged in 90 days", activeUsersPasswordUnchangedIn90Days, activeUsersCount);
                WriteStatistic("Active users with Administrator rights", activeUsersWithAdministratorMembership.Length, activeUsersCount);
                WriteStatistic("Active users with Domain Admin rights", activeUsersWithDomainAdminMembership.Length, activeUsersCount);
                WriteStatistic("Active users with Enterprise Admin rights", activeUsersWithEnterpriseAdminMembership.Length, activeUsersCount);
                Console.WriteLine();

                var computers = ntdsAudit.Computers.Where(x => x.DomainSid.Equals(domain.Sid)).ToList();
                var totalComputersCount = computers.Count;
                var disabledComputersCount = computers.Count(x => x.Disabled);
                var activeComputers = computers.Where(x => !x.Disabled).ToList();
                var activeComputersCount = activeComputers.Count;
                var activeComputersUnusedIn1Year = activeComputers.Count(x => x.LastLogon + TimeSpan.FromDays(365) < baseDateTime);
                var activeComputersUnusedIn90Days = activeComputers.Count(x => x.LastLogon + TimeSpan.FromDays(90) < baseDateTime);

                WriteStatistic("Disabled computers", disabledComputersCount, totalComputersCount);
                WriteStatistic("Active computers unused in 1 year", activeComputersUnusedIn1Year, activeComputersCount);
                WriteStatistic("Active computers unused in 90 days", activeComputersUnusedIn90Days, activeComputersCount);
                Console.WriteLine();
            }
        }

        private static void WriteComputersCsvFile(string computersCsvPath, NtdsAudit ntdsAudit, DateTime baseDateTime)
        {
            using (var file = new StreamWriter(computersCsvPath, false))
            {
                file.WriteLine("Domain,Computer,Disabled,Last Logon,DN");
                foreach (var computer in ntdsAudit.Computers)
                {
                    var domain = ntdsAudit.Domains.Single(x => x.Sid == computer.DomainSid);
                    file.WriteLine($"{domain.Fqdn},{computer.Name},{computer.Disabled},{computer.LastLogon},\"{computer.Dn}\"");
                }
            }
        }

        private static void WritePwDumpFile(string pwdumpPath, NtdsAudit ntdsAudit, DateTime baseDateTime, bool includeHistoryHashes, bool wordlistInUse, string dumpReversiblePath)
        {
            DomainInfo domain = null;

            // NTDS will only contain hashes for a single domain, even when NTDS was dumped from a global catalog server, ensure we only print hashes for that domain, and warn the user if there are other domains in NTDS
            if (ntdsAudit.Domains.Length > 1)
            {
                var usersWithHashes = ntdsAudit.Users.Where(x => x.LmHash != NtdsAudit.EMPTY_LM_HASH || x.NtHash != NtdsAudit.EMPTY_NT_HASH).ToList();
                domain = ntdsAudit.Domains.Single(x => x.Sid.Equals(usersWithHashes[0].DomainSid));

                ConsoleEx.WriteWarning($"WARNING:");
                ConsoleEx.WriteWarning($"The NTDS file has been retrieved from a global catalog (GC) server. Whilst GCs store information for other domains, they only store password hashes for their primary domain.");
                ConsoleEx.WriteWarning($"Password hashes have only been dumped for the \"{domain.Fqdn}\" domain.");
                ConsoleEx.WriteWarning($"If you require password hashes for other domains, please obtain the NTDS and SYSTEM files for each domain.");
                Console.WriteLine();
            }
            else
            {
                domain = ntdsAudit.Domains[0];
            }

            var users = ntdsAudit.Users.Where(x => domain.Sid.Equals(x.DomainSid)).ToArray();

            if (users.Any(x => !string.IsNullOrEmpty(x.ClearTextPassword)))
            {
                ConsoleEx.WriteWarning($"WARNING:");
                ConsoleEx.WriteWarning($"The NTDS file contains user accounts with passwords stored using reversible encryption. Use the --dump-reversible option to output these users and passwords.");
                Console.WriteLine();
            }

            var activeUsers = users.Where(x => !x.Disabled && (!x.Expires.HasValue || x.Expires.Value > baseDateTime)).ToArray();
            var activeUsersWithLMs = activeUsers.Where(x => !string.IsNullOrEmpty(x.LmHash) && x.LmHash != NtdsAudit.EMPTY_LM_HASH).ToArray();
            var activeUsersWithWeakPasswords = activeUsers.Where(x => !string.IsNullOrEmpty(x.Password)).ToArray();
            var activeUsersWithDuplicatePasswordsCount = activeUsers.Where(x => x.NtHash != NtdsAudit.EMPTY_NT_HASH).GroupBy(x => x.NtHash).Where(g => g.Count() > 1).Sum(g => g.Count());
            var activeUsersWithPasswordStoredUsingReversibleEncryption = activeUsers.Where(x => !string.IsNullOrEmpty(x.ClearTextPassword)).ToArray();

            Console.WriteLine($"Password stats for: {domain.Fqdn}");
            WriteStatistic("Active users using LM hashing", activeUsersWithLMs.Length, activeUsers.Length);
            WriteStatistic("Active users with duplicate passwords", activeUsersWithDuplicatePasswordsCount, activeUsers.Length);
            WriteStatistic("Active users with password stored using reversible encryption", activeUsersWithPasswordStoredUsingReversibleEncryption.Length, activeUsers.Length);
            if (wordlistInUse)
            {
                WriteStatistic("Active user accounts with very weak passwords", activeUsersWithWeakPasswords.Length, activeUsers.Length);
            }

            Console.WriteLine();

            // <username>:<uid>:<LM-hash>:<NTLM-hash>:<comment>:<homedir>:
            using (var file = new StreamWriter(pwdumpPath, false))
            {
                for (var i = 0; i < users.Length; i++)
                {
                    var comments = $"Disabled={users[i].Disabled}," +
                        $"Expired={!users[i].Disabled && users[i].Expires.HasValue && users[i].Expires.Value < baseDateTime}," +
                        $"PasswordNeverExpires={users[i].PasswordNeverExpires}," +
                        $"PasswordNotRequired={users[i].PasswordNotRequired}," +
                        $"PasswordLastChanged={users[i].PasswordLastChanged.ToString("yyyyMMddHHmm")}," +
                        $"LastLogonTimestamp={users[i].LastLogon.ToString("yyyyMMddHHmm")}," +
                        $"IsAdministrator={users[i].RecursiveGroupSids.Contains(domain.AdministratorsSid)}," +
                        $"IsDomainAdmin={users[i].RecursiveGroupSids.Contains(domain.DomainAdminsSid)}," +
                        $"IsEnterpriseAdmin={users[i].RecursiveGroupSids.Intersect(ntdsAudit.Domains.Select(x => x.EnterpriseAdminsSid)).Any()}";
                    var homeDir = string.Empty;
                    file.Write($"{domain.Fqdn}\\{users[i].SamAccountName}:{users[i].Rid}:{users[i].LmHash}:{users[i].NtHash}:{comments}:{homeDir}:");

                    if (includeHistoryHashes && users[i].NtHistory != null && users[i].NtHistory.Length > 0)
                    {
                        file.Write(Environment.NewLine);
                    }
                    else if (i < users.Length - 1)
                    {
                        file.Write(Environment.NewLine);
                    }

                    if (includeHistoryHashes && users[i].NtHistory != null && users[i].NtHistory.Length > 0)
                    {
                        for (var j = 0; j < users[i].NtHistory.Length; j++)
                        {
                            var lmHash = (users[i].LmHistory?.Length > j) ? users[i].LmHistory[j] : NtdsAudit.EMPTY_LM_HASH;
                            file.Write($"{domain.Fqdn}\\{users[i].SamAccountName}__history_{j}:{users[i].Rid}:{lmHash}:{users[i].NtHistory[j]}:::");

                            if (j < users[i].NtHistory.Length || i < users.Length - 1)
                            {
                                file.Write(Environment.NewLine);
                            }
                        }
                    }
                }
            }

            if (users.Any(x => !string.IsNullOrEmpty(x.ClearTextPassword)) && !string.IsNullOrWhiteSpace(dumpReversiblePath))
            {
                using (var file = new StreamWriter(dumpReversiblePath, false))
                {
                    for (var i = 0; i < users.Length; i++)
                    {
                        if (!string.IsNullOrEmpty(users[i].ClearTextPassword))
                        {
                            file.Write($"{domain.Fqdn}\\{users[i].SamAccountName}:{users[i].ClearTextPassword}");

                            if (i < users.Length - 1)
                            {
                                file.Write(Environment.NewLine);
                            }
                        }
                    }
                }
            }
        }

        private static void WriteStatistic(string statistic, int actual, int maximum)
        {
            Console.Write($"  {statistic} ".PadRight(70, '_'));
            var percentageString = (maximum < 1) ? "N/A" : GetPercentage(actual, maximum) + "%";
            Console.Write($" {actual.ToString().PadLeft(5)} of {maximum.ToString().PadLeft(5)} ({percentageString})");
            Console.Write(Environment.NewLine);
        }

        private static string GetCSVStatistic(string statistic, int actual, int maximum)
        {
            string ret= $"\"{statistic}\",\"";
            var percentageString = (maximum < 1) ? "N/A" : GetPercentage(actual, maximum) + "%";
            ret += $"{actual.ToString().PadLeft(5)} of {maximum.ToString().PadLeft(5)} ({percentageString})\"";
            return ret;
        }


        private static void WriteUsersCsvFile(string usersCsvPath, NtdsAudit ntdsAudit, DateTime baseDateTime, string potFile)
        {
            int nbUsers = ntdsAudit.Users.Length;
            Console.WriteLine($"[*] Extracting {nbUsers} users...");
            var progress = new ProgressBar("Performing users extraction...");

            // Buffer des group
            Dictionary<string, string> groupAssoc = new Dictionary<string, string>();
            foreach (var group in ntdsAudit.Groups)
            {
                try {
                    groupAssoc.Add(group.Sid.ToString(), group.Name);
                }
                catch
                {
                    if (groupAssoc[group.Sid.ToString()] != group.Name)
                    {
                        Console.WriteLine($"[*] Double SID with different name ! {group.Sid.ToString()} => \"{group.Name}\" and \"{groupAssoc[group.Sid.ToString()]}\"");
                    }
                }
            }

            // Buffer des hash
            Console.WriteLine($"[*] Reading potfile potFile={potFile}");
            Dictionary<string, string> hashAssoc = new Dictionary<string, string>();
            if( File.Exists(potFile) )
            {
                using (var file = new StreamReader(potFile))
                {
                    string line;
                    while ((line = file.ReadLine()) != null)
                    {
                        if (line.Length == 33)
                        {
                            hashAssoc.Add(line.Substring(0, 32), string.Empty);
                        }
                        else
                        {
                            try
                            {
                                hashAssoc.Add(line.Substring(0, 32).ToLower(), line.Substring(33));
                            }
                            catch
                            {
                                Console.WriteLine("Invalid hash size for " + line);
                            }
                        }
                    }
                }
            }
            else
            {
                Console.WriteLine("[!] No potfile not found or --potfile missing !");
            }

            var samePassword = new Dictionary<string, AssocPassHash>();
            int nbCompromised = 0;
            int nbCompromisedAndEnabled = 0;
            int nbCompromisedAndEnabledAndAdmin = 0;
            int nbCompromisedAndAdmin = 0;
            using (var file = new StreamWriter(usersCsvPath, false))
            {
                int i = 1;
                file.WriteLine("Sid,Domain,Username,PasswordFound,IsAdminWithLowPassword,isAdminInAnyGroup,Administrator,Domain Admin,Enterprise Admin,Disabled,Expired,Password Never Expires,Password Not Required,Password Last Changed,Last Logon,Hash,Password,PasswordLen,MemberOf,Count in group,Dn");
                foreach (var user in ntdsAudit.Users)
                {
                    var domain = ntdsAudit.Domains.Single(x => x.Sid == user.DomainSid);
                    string password;
                    string hash = user.NtHash.ToLower();
                    int passwordLen = -1;
                    bool isAdmin = user.RecursiveGroupSids.Contains(domain.AdministratorsSid) || user.RecursiveGroupSids.Contains(domain.DomainAdminsSid) || user.RecursiveGroupSids.Intersect(ntdsAudit.Domains.Select(x => x.EnterpriseAdminsSid)).Any();
                    try
                    {
                        password = hashAssoc[hash];
                        passwordLen = password.Length;
                        if (passwordLen == 0)
                        {
                            password = "<EMPTY>";
                        }
                        nbCompromised += 1;
                        if( user.Disabled != true)
                        {
                            nbCompromisedAndEnabled += 1;
                            if (isAdmin)
                            {
                                nbCompromisedAndEnabledAndAdmin += 1;
                            }
                        }
                        if (isAdmin)
                        {
                            nbCompromisedAndAdmin += 1;
                        }
                    }
                    catch (Exception e)
                    {
                        password = "<NOT FOUND>";
                        passwordLen = -1;
                    }
                    bool isAdminWithLowPassword = isAdmin && passwordLen > -1;
                    bool isPasswordFound = passwordLen > -1;
                    file.Write($"{user.DomainSid}-{user.Rid},{domain.Fqdn},{user.SamAccountName},{isPasswordFound},{isAdminWithLowPassword},{isAdmin},{user.RecursiveGroupSids.Contains(domain.AdministratorsSid)},{user.RecursiveGroupSids.Contains(domain.DomainAdminsSid)},{user.RecursiveGroupSids.Intersect(ntdsAudit.Domains.Select(x => x.EnterpriseAdminsSid)).Any()},{user.Disabled},{!user.Disabled && user.Expires.HasValue && user.Expires.Value < baseDateTime},{user.PasswordNeverExpires},{user.PasswordNotRequired},{user.PasswordLastChanged},{user.LastLogon},{user.LmHash}:{user.NtHash},\"{password}\",{passwordLen},\"");
                    foreach (SecurityIdentifier si in user.RecursiveGroupSids)
                    {
                        try
                        {
                            file.Write(groupAssoc[si.ToString()] + " / ");
                        }
                        catch
                        {
                            file.Write($"<unk {si.ToString()}> / ");
                        }
                    }
                    file.Write($"\",{user.RecursiveGroupSids.Length},\"{user.Dn}\"\n");


                    if ( !samePassword.ContainsKey(hash) ){
                        samePassword.Add(hash, new AssocPassHash(hash, password, passwordLen));
                    }
                    samePassword[hash].count += 1;

                    progress.Report((100 * i / nbUsers) / 100.0);
                    ++i;
                }
            }
            
            var stats = samePassword.OrderByDescending(x => x.Value.count);
            using (var file = new StreamWriter(usersCsvPath.Replace(".csv",string.Empty)+ "-PasswordReuse.csv", false))
            {
                int i = 1;
                file.WriteLine("Hash,Password,Count");
                foreach (var h in stats)
                {
                    if(h.Value.count <= 1)
                    {
                        break;
                    }
                    file.WriteLine($"\"{h.Value.hash}\",\"{h.Value.pass.Replace("\"","\\\\\"")}\",{h.Value.count}");
                }
            }
            using (var file = new StreamWriter(usersCsvPath.Replace(".csv", string.Empty) + "-Stats.csv", false))
            {
                int nbAccount = ntdsAudit.Users.Count();
                var expiredUsersCount = ntdsAudit.Users.Count(x => !x.Disabled && x.Expires.HasValue && x.Expires.Value < baseDateTime);
                var activeUsers = ntdsAudit.Users.Where(x => !x.Disabled && (!x.Expires.HasValue || x.Expires.Value > baseDateTime)).ToList();
                var activeUsersCount = activeUsers.Count;
                var activeUsersUnusedIn1Year = activeUsers.Count(x => x.LastLogon + TimeSpan.FromDays(365) < baseDateTime);
                var activeUsersUnusedIn90Days = activeUsers.Count(x => x.LastLogon + TimeSpan.FromDays(90) < baseDateTime);
                var activeUsersWithPasswordNotRequired = activeUsers.Count(x => x.PasswordNotRequired);
                var activeUsersWithPasswordNeverExpires = activeUsers.Count(x => !x.PasswordNeverExpires);
                var activeUsersPasswordUnchangedIn1Year = activeUsers.Count(x => x.PasswordLastChanged + TimeSpan.FromDays(365) < baseDateTime);
                var activeUsersPasswordUnchangedIn90Days = activeUsers.Count(x => x.PasswordLastChanged + TimeSpan.FromDays(90) < baseDateTime);
                file.WriteLine($"\"Number of account\",{nbAccount}");
                file.WriteLine($"\"Active account (Enabled and not password not expired)\",{activeUsersCount}");
                file.WriteLine(GetCSVStatistic("Disabled users", ntdsAudit.Users.Count(x => x.Disabled), nbAccount));
                file.WriteLine(GetCSVStatistic("Expired users", expiredUsersCount, nbAccount));
                file.WriteLine(GetCSVStatistic("Active users unused in 1 year", activeUsersUnusedIn1Year, activeUsersCount));
                file.WriteLine(GetCSVStatistic("Active users unused in 90 days", activeUsersUnusedIn90Days, activeUsersCount));
                file.WriteLine(GetCSVStatistic("Active users which do not require a password", activeUsersWithPasswordNotRequired, activeUsersCount));
                file.WriteLine(GetCSVStatistic("Active users with non-expiring passwords", activeUsersWithPasswordNeverExpires, activeUsersCount));
                file.WriteLine(GetCSVStatistic("Active users with password unchanged in 1 year", activeUsersPasswordUnchangedIn1Year, activeUsersCount));
                file.WriteLine(GetCSVStatistic("Active users with password unchanged in 90 days", activeUsersPasswordUnchangedIn90Days, activeUsersCount));

                foreach (var domain in ntdsAudit.Domains)
                {
                    var activeUsersWithAdministratorMembership = activeUsers.Where(x => x.RecursiveGroupSids.Contains(domain.AdministratorsSid)).ToArray();
                    var activeUsersWithDomainAdminMembership = activeUsers.Where(x => x.RecursiveGroupSids.Contains(domain.DomainAdminsSid)).ToArray();
                    // Unlike Domain Admins and Adminsitrators, Enterprise Admins is not domain local, so include all users.
                    var activeUsersWithEnterpriseAdminMembership = ntdsAudit.Users.Where(x => !x.Disabled && (!x.Expires.HasValue || x.Expires.Value > baseDateTime) && x.RecursiveGroupSids.Contains(domain.EnterpriseAdminsSid)).ToArray();
                    file.WriteLine(GetCSVStatistic($"Active users with Administrator rights (domain={domain.Name})", activeUsersWithAdministratorMembership.Length, activeUsersCount));
                    file.WriteLine(GetCSVStatistic($"Active users with Domain Admin rights (domain={domain.Name})", activeUsersWithDomainAdminMembership.Length, activeUsersCount));
                    file.WriteLine(GetCSVStatistic($"Active users with Enterprise Admin rights (domain={domain.Name})", activeUsersWithEnterpriseAdminMembership.Length, activeUsersCount));
                }
                file.WriteLine($"\"Number of compromised accounts\",\"{nbCompromised} ({nbCompromised*100/ nbAccount}%)\"");
                file.WriteLine($"\"Number of compromised accounts with enabled flag\",\"{nbCompromisedAndEnabled} ({nbCompromisedAndEnabled * 100 / nbAccount}%)\"");
                file.WriteLine($"\"Number of compromised accounts with admin priviledge\",\"{nbCompromisedAndAdmin} ({nbCompromisedAndAdmin * 100 / nbAccount}%)\"");
                file.WriteLine($"\"Number of compromised accounts, enabled and admin\",\"{nbCompromisedAndEnabledAndAdmin} ({nbCompromisedAndEnabledAndAdmin * 100 / nbAccount}%)\"");
                file.WriteLine(string.Empty);
                for (int i = 0; i <= 30; ++i)
                {
                    file.WriteLine($"\"Passwword with a length of {i}\",{samePassword.Where(x => x.Value.len == i).Count()}");
                }
            }
            progress.Report(1);
        }
    }
}