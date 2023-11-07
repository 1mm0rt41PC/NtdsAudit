import sys,os
import xlsxwriter
import csv

maxInt = sys.maxsize
while True:
	# decrease the maxInt value by factor 10 
	# as long as the OverflowError occurs.
	try:
		csv.field_size_limit(maxInt)
		break
	except OverflowError:
		maxInt = int(maxInt/10)

# Initialize the excel output file
excel_file_path = r'/output/PasswordPolicy.xlsx'
wb			    = xlsxwriter.Workbook(excel_file_path)

wb_stats		= wb.add_worksheet('Statistics')
wb_stats.insert_image('A1', './Background.png')
wb_stats.set_row(0, 180)  # Set the height of Row 1 to 20.


with open(r'/import/Report-Stats.csv', mode='r', encoding='utf8') as csv_file:
	csv_reader = csv.DictReader(csv_file)
	wb_stats.set_column(0,0, 100)
	i = 1
	#wb_stats.write(i, 0, "Info")
	#wb_stats.write(i, 1, "Number")
	for row in csv_reader:
		wb_stats.write(i, 0, row["Info"])
		wb_stats.write_number(i, 1, int(row["Number"],10))
		i+=1
	wb_stats.add_table('A2:B15',{'header_row': False, 'style': 'TableStyleMedium4'})


with open(r'/import/Report-Passwords-length.csv', mode='r', encoding='utf8') as csv_file:
	csv_reader = csv.DictReader(csv_file)
	wb_stats.set_column(3,3, 40)
	i = 2
	nbLine = 0
	for row in csv_reader:
		wb_stats.write(i, 3, row["Info"])
		wb_stats.write_number(i, 4, int(row["Number of"],10))
		i+=1
		nbLine+=1
	wb_stats.add_table(f'D2:E{nbLine+2}',{'header_row': True, 'style': 'TableStyleMedium4',"columns": [
		{"header": "Info"},
		{"header": "Number of"},
	]})
	
	chart1 = wb.add_chart({"type": "bar"})
	# Add a chart title and some axis labels.
	chart1.set_title({"name": "Passwords length"})
	#chart1.set_x_axis({"name": "Test number"})
	#chart1.set_y_axis({"name": "Sample length (mm)"})
	chart1.set_legend({'none': True})
	chart1.add_series({
		"name": "Passwords length",
		"categories": f"=Statistics!$D$4:$D${2+nbLine}",
		"values": f"=Statistics!$E$4:$E${2+nbLine}",
	})
	# Set an Excel chart style.
	chart1.set_style(11)
	wb_stats.insert_chart("F2", chart1, {"x_offset": 25, "y_offset": 0, 'x_scale': 1.5, 'y_scale': 1.5})


ws		= wb.add_worksheet('Password reuse')
with open(r'/import/Report-List-of-password-reuse.csv', mode='r', encoding='utf8') as csv_file:
	csv_reader = csv.DictReader(csv_file)
	ws.set_column(0,0, 30)
	ws.set_column(2,2, 30)
	
	i=0
	for row in csv_reader:
		ws.write(i, 0, row["Hash"])
		ws.write_number(i, 1, int(row["Reused"],10))
		ws.write(i, 2, row["ClearText"])
		i+=1
	ws.add_table(f'A1:C{i}',{'header_row': True, 'style': 'TableStyleMedium4',"columns": [
		{"header": "NtHash"},
		{"header": "Reused"},
		{"header": "ClearText"},
	]})


ws		= wb.add_worksheet('Password with banned words')
with open(r'/import/Report-List-of-banned-passwords.csv', mode='r', encoding='utf8') as csv_file:
	csv_reader = csv.DictReader(csv_file)
	ws.set_column(0,0, 30)
	ws.set_column(2,2, 30)
	
	i=0
	for row in csv_reader:
		ws.write(i, 0, row["NtHash"])
		ws.write_number(i, 1, int(row["Reused"],10))
		ws.write(i, 2, row["ClearText"])
		i+=1
	ws.add_table(f'A1:C{i}',{'header_row': True, 'style': 'TableStyleMedium4',"columns": [
		{"header": "NtHash"},
		{"header": "Reused"},
		{"header": "ClearText"},
	]})


ws		= wb.add_worksheet('Users')
with open(r'/import/Report-List-Of-Users.csv', mode='r', encoding='utf8') as csv_file:
	csv_reader = csv.DictReader(csv_file)
	format1 = wb.add_format({"bg_color": "#FFC7CE", "font_color": "#9C0006"})
	
	i=0
	for row in csv_reader:
		c=0
		for col in csv_reader.fieldnames:
			try:
				ws.write_number(i, c, int(row[col],10))
			except:
				if row[col] == 'true':
					ws.write_boolean(i, c, True)
				elif row[col] == 'false':
					ws.write_boolean(i, c, False)
				else:
					ws.write(i, c, row[col])
			c +=1
		i+=1
	cols = []
	for col in csv_reader.fieldnames:
		cols.append({"header":col})
	ws.add_table(f'A1:{chr(ord("A")+len(cols)-1)}{i}',{'header_row': True, 'style': 'TableStyleMedium4',"columns": cols})
	ws.autofit()
	ws.conditional_format(f'F2:G{i+1}',{
		'type':     'cell',	
		'criteria': '=',
		'value':    'true',
		'format':   format1
	})
	ws.conditional_format(f'I2:I{i+1}',{
		'type':     'cell',	
		'criteria': '=',
		'value':    'true',
		'format':   format1
	})
	ws.conditional_format(f'N2:Q{i+1}',{
		'type':     'cell',	
		'criteria': '=',
		'value':    'true',
		'format':   format1
	})
	ws.conditional_format(f'S2:S{i+1}',{
		'type':     'cell',	
		'criteria': '>=',
		'value':    1,
		'format':   format1
	})
	ws.conditional_format(f'H2:H{i+1}',{
		'type':     'cell',	
		'criteria': '>=',
		'value':    0,
		'format':   format1
	})

wb.close()