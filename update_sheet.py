import sys
import httplib2
import os

from apiclient import discovery
from google.oauth2 import service_account

try:
    scopes = ["https://www.googleapis.com/auth/drive", "https://www.googleapis.com/auth/drive.file", "https://www.googleapis.com/auth/spreadsheets"]
    secret_file = os.path.join(os.getcwd(), 'client_secret.json')

    credentials = service_account.Credentials.from_service_account_file(secret_file, scopes=scopes)
    service = discovery.build('sheets', 'v4', credentials=credentials)
    
    SAMPLE_SPREADSHEET_ID = 'example' # Replace with spreadsheet ID
    INVENTORY_SPREADSHEET = sys.argv[1]
    COLS = ''.join(sys.argv[2:]).split(';')
    TARGET_SHEET = COLS[0]

    # Read the current values in column B of the "ALL" sheet
    ALL_SHEET_RANGE_NAME = 'AUDIT TOOL!B:B'
    result_all = service.spreadsheets().values().get(spreadsheetId=SAMPLE_SPREADSHEET_ID, range=ALL_SHEET_RANGE_NAME).execute()
    values_all = result_all.get('values', [])

    if not values_all:
        # If the "ALL" sheet is empty, start with 1
        new_first_col_value = '?'
    else:
        try:
            # Try to increment the most recent value in "ALL" by 1
            new_first_col_value = int(values_all[-1][0]) + 1
        except ValueError:
            # If the most recent value is not a number, set the value to '?'
            new_first_col_value = '?'

    # Prepend the new first column value (SKU) to COLS[1:]
    new_row = [new_first_col_value] + COLS[1:]

    # Prepend the target sheet name to the new row and append it to the "ALL" sheet
    new_row_with_sheet_name = [TARGET_SHEET] + new_row
    Body_ALL = {'values': [new_row_with_sheet_name], 'majorDimension': 'ROWS'}
    service.spreadsheets().values().append(
        spreadsheetId=SAMPLE_SPREADSHEET_ID,
        range=ALL_SHEET_RANGE_NAME,
        valueInputOption='RAW',
        body=Body_ALL
    ).execute()

except OSError as e:
    print(e)

