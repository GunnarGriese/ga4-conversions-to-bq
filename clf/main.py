import os
from dotenv import load_dotenv
import time
import datetime

from google.cloud import bigquery
from google.analytics.admin import AnalyticsAdminServiceClient

# Load environment variables from .env file
load_dotenv()

# GA4 settings
ga4_client = AnalyticsAdminServiceClient()
property_list_str = os.getenv('GA4_PROPERTY_LIST', '')
property_list = property_list_str.split(',')

# BQ settings
PROJECT_ID = os.getenv('GCP_PROJECT_ID')
TABLE_ID = os.getenv('GCP_TABLE_ID')
bq_client = bigquery.Client(project=PROJECT_ID)
bq_schema = [
            bigquery.SchemaField("date", "DATE", mode="REQUIRED"),
            bigquery.SchemaField("property_id", "STRING"),
            bigquery.SchemaField("conversion_api_name", "STRING"),
            bigquery.SchemaField("event_name", "STRING"),
            bigquery.SchemaField("create_time", "TIMESTAMP"),
            bigquery.SchemaField("counting_method", "STRING"),
        ]

def get_ga4_conversions(property_id, conversion_results):

    today = datetime.date.today().strftime('%Y-%m-%d')

    ga4_resp = ga4_client.list_conversion_events(parent=f"properties/{property_id}")
    for conversion_event in ga4_resp:
        print(conversion_event.create_time.isoformat())
        conversion_results.append(
            {
                "date": today,
                "property_id": property_id,
                "conversion_api_name": conversion_event.name,
                "event_name": conversion_event.event_name,
                "create_time": conversion_event.create_time.isoformat(),
                "counting_method": conversion_event.counting_method.name,
            }
        )
    return conversion_results

def bq_upload(data):
    success = False
    # Check for table and create if it doesn't exist
    print(data)
    try:
        table = bq_client.get_table(TABLE_ID)
    except:
        table = bigquery.Table(TABLE_ID, schema=bq_schema)
        bq_client.create_table(table)
        time.sleep(10)

    # Upload data
    job_config = bigquery.LoadJobConfig(
        schema=bq_schema,
        write_disposition="WRITE_APPEND",
    )
    job = bq_client.load_table_from_json(data, TABLE_ID, job_config=job_config)
    job.result()
    print("Uploaded {} rows to {}.".format(job.output_rows, TABLE_ID))

    success = True
    
    return success

def main(request):
    start_time = time.time()
    print("Execution started.")
    conversion_results = []
    for property_id in property_list:
        get_ga4_conversions(property_id, conversion_results)

    if conversion_results:
        bq_upload(conversion_results)

    end_time = time.time()
    print(f"Execution finished. Duration: {end_time - start_time} seconds.")
    
    return ("Success", 200)

if __name__ == "__main__":
    main(None)


