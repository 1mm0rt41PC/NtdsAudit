import sys,os
import xlsxwriter
import csv
from base64 import b64decode

if len(sys.argv) >= 2 and '--no-docker' in sys.argv:
	_XSLX_OUTPUT = './output/PasswordPolicy.xlsx'
	_CSV_PATH = './neo4j-import/'
else:
	_XSLX_OUTPUT = '/output/PasswordPolicy.xlsx'
	_CSV_PATH = '/import/'
_APPEND_B64_CLEAR_PASS = len(sys.argv) >= 2 and '--clear-pass' in sys.argv


maxInt = sys.maxsize
while True:
	# decrease the maxInt value by factor 10
	# as long as the OverflowError occurs.
	try:
		csv.field_size_limit(maxInt)
		break
	except OverflowError:
		maxInt = int(maxInt/10)


def main():
	print(f'[+] Creating {_XSLX_OUTPUT}')
	wb = xlsxwriter.Workbook(_XSLX_OUTPUT)

	print(f'[+] Add sensitives datas (password in cleartext): {_APPEND_B64_CLEAR_PASS}')

	ws = wb.add_worksheet('Statistics')
	ws.insert_image('A1', './Background.png')
	ws.set_row(0, 180)  # Set the height of Row 1 to 20.ws = wb.add_worksheet('Users')
	loadCSV(f'Report-Stats.csv', ws, 'A', 2, False)
	lastRow,colNames = loadCSV(f'Report-Passwords-length.csv', ws, 'D', 2, True)
	chart1 = wb.add_chart({"type": "bar"})
	# Add a chart title and some axis labels.
	chart1.set_title({"name": "Passwords length"})
	#chart1.set_x_axis({"name": "Test number"})
	#chart1.set_y_axis({"name": "Sample length (mm)"})
	chart1.set_legend({'none': True})
	chart1.add_series({
		"name": "Passwords length",
		"categories": f"=Statistics!$D$4:$D${lastRow}",
		"values": f"=Statistics!$E$4:$E${lastRow}",
	})
	# Set an Excel chart style.
	chart1.set_style(11)
	ws.insert_chart("F2", chart1, {"x_offset": 25, "y_offset": 0, 'x_scale': 1.5, 'y_scale': 1.5})


	ws = wb.add_worksheet('Password reuse')
	loadCSV(f'Report-List-of-password-reuse.csv', ws, 'A', 1, True)

	ws = wb.add_worksheet('Password with banned words')
	loadCSV(f'Report-List-of-banned-passwords.csv', ws, 'A', 1, True)

	ws = wb.add_worksheet('Users')
	lastRow,colNames = loadCSV(f'Report-List-Of-Users.csv', ws, 'A', 1, True)
	format1 = wb.add_format({"bg_color": "#FFC7CE", "font_color": "#9C0006"})
	
	columnCheck = {
		'Weak password': 'true',
		'Password containing a forbidden word': 'true',
		'Password length': 1,
		'Password never expires': 'true',
		'Password leaked on the Internet': 'true',
		'Password not required': 'true',
		'Unconstrained Delegation': 'true',
		'Has SPN': 'true',
		'Was in a Tier0 group': 'true',
		'Member Of Tier0': 'true',
		'Number of items of Tier0 that can be compromised': 1,
		'Number of items that can be compromised': 1
	}
	for colName in columnCheck:
		colPos = chr(colNames.index(colName)+ord('A'))
		criteria = '>=' if columnCheck[colName] == 1 else '='
		print(f'[+]     > Adding format {criteria}{columnCheck[colName]} on {colName}={colPos}2:{colPos}{lastRow+1}')
		ws.conditional_format(f'{colPos}2:{colPos}{lastRow+1}',{
			'type':     'cell',
			'criteria': criteria,
			'value':    columnCheck[colName],
			'format':   format1
		})

	ws = wb.add_worksheet('Definition')
	lastRow = loadCSV(f'Report-Definition-T0.csv', ws, 'A', 1, True)

	print(f'[+] Saving {_XSLX_OUTPUT}')
	wb.close()


def loadCSV( sfile, ws, iCol, iRow, header_row ) -> (int,list):
	sfile = _CSV_PATH+sfile
	print(f'[+] Reading {sfile}')
	with open(sfile, mode='r', encoding='utf8') as fp:
		csv_reader = csv.DictReader(fp)
		iCol_it = ord(iCol)-ord('A')
		iRow -= 1
		i = iRow+1 if header_row else iRow
		print(f'[+]     > Loading data to {sfile} col={iCol_it}, row={iRow} => {iCol}{iRow+1}')
		for row in csv_reader:
			c = iCol_it
			for col in csv_reader.fieldnames:
				try:
					if col.startswith('Secret:'):
						if _APPEND_B64_CLEAR_PASS:
							ws.write(i, c, row[col])
						else:
							c-=1
					else:
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
		print(f'[+]     > Loaded {i-iRow} lines')
		cols = []
		for col in csv_reader.fieldnames:
			if _APPEND_B64_CLEAR_PASS:
				cols.append({"header":col})
			elif not col.startswith('Secret:'):
				cols.append({"header":col})
		tabPos = f'{iCol}{iRow+1}:{chr(ord("A")+iCol_it+len(cols)-1)}{i}'
		print(f'[+]     > Creating table at {tabPos}')
		ws.add_table(tabPos,{'header_row': header_row, 'style': 'TableStyleMedium4',"columns": cols})
		ws.autofit()
		return (i,csv_reader.fieldnames)
	return (-1,list)

main()