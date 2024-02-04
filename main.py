import time
import datetime

from google.cloud import bigquery
from google.analytics.admin import AnalyticsAdminServiceClient

# GA4 settings
ga4_client = AnalyticsAdminServiceClient()
property_list = [
    "250400352", # 📠 GA4 - gunnargriese.com (prod)
    "401777267", # 📠 GA4 - gunnargriese.com (internal traffic)

]

# BQ settings
PROJECT_ID = "nlp-api-test-260216"
TABLE_ID = "nlp-api-test-260216.analytics_conversions.ga4_conversions"
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
        conversion_results.append(
            {
                "date": today,
                "property_id": property_id,
                "conversion_api_name": conversion_event.name,
                "event_name": conversion_event.event_name,
                "create_time": datetime.datetime.fromisoformat(conversion_event.create_time.isoformat()).isoformat(),
                "counting_method": conversion_event.counting_method.name,
            }
        )
    return

def bq_upload(data):
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
    print(f"Uploading {len(data)} rows to {TABLE_ID}.")
    job = bq_client.load_table_from_json(data, TABLE_ID, job_config=job_config)
    job.result()
    print("Uploaded {} rows to {}.".format(job.output_rows, TABLE_ID))
    
    return

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
    
    return (200, "Success")

if __name__ == "__main__":
    main(None)
    print("Done.")


