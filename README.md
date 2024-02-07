# ga4-conversions-to-bq

This repository contains a Python script that uses the Google Analytics Admin API to pull conversion data from Google Analytics 4 (GA4) and load it into BigQuery.

## Prerequisites

1. A Google Analytics 4 (GA4) property.
2. A Google Cloud Platform (GCP) project with billing and the Google Analytics Admin API enabled.
3. A BigQuery dataset to store the conversion data (or the script will create it for you).

## Setup

1. Enable the Google Analytics Admin API in the Google Cloud Console.
2. Add the Compute Engine default service account (`<your-project-id>-compute@developer.gserviceaccount.com`) as a user in the GA4 property with the "Viewer" permission.
3. Add a `.env.yaml` file to include the following environment variables:

```yaml
GCP_PROJECT_ID: <your-project-id>
GCP_TABLE_ID: <your-project-id>.<your-dataset-id>.<your-table-id>>
GA4_PROPERTY_LIST: "123456789, 345678901" # Comma-separated list of GA4 property IDs to fetch the conversion metadata from
```

4. Deploy the `main.py` script to a Cloud Function using the `/clf/deploy-clf.sh` script:

```bash
gcloud functions deploy your-function-name --runtime python39 --trigger-http --env-vars-file .env.yaml --region your-region --entry-point main --timeout 540s --ingress-settings all --gen2
```

5. Schedule the Cloud Function to run at regular intervals via Cloud Scheduler using the `/cls/deploy-cls.sh` script:

```bash
gcloud scheduler jobs create http your-job-name --schedule "0 0 * * *" --uri "https://<your-region-your-project-id>.cloudfunctions.net/<your-function-name>" --http-method GET --time-zone "Europe/Copenhagen"
```

## Usage

The Cloud Function will run at the scheduled intervals and pull the conversion data from GA4 and load it into BigQuery. The resulting dataset will contain the following columns:

- `date`(DATE) - The date of the conversion.
- `property_id`(STRING) - The GA4 property ID.
- `conversion_api_name`(STRING) - The API name of the conversion.
- `event_name`(STRING) - The event name of the conversion.
- `custom_event`(BOOL) - Whether the conversion is a custom event.
- `deletable`(BOOL) - Whether the conversion is deletable.
- `create_time`(TIMESTAMP) - The time the conversion was created.
- `counting_method`(STRING) - The counting method of the conversion.
- `default_conversion_value`(FLOAT) - The default conversion value.
- `default_conversion_value_currency_code`(STRING) - The currency code of the default conversion value.

This table can be joined with your GA4 event data to analyze the performance of your conversions. See the `/bq/conversions.sql` file for an example query. Please note that the `counting_method` column affects how the conversion data is counted and should be taken into account when analyzing the data.

Read my full blog post [here](https://gunnargriese.com) for more information.
