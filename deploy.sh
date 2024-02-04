gcloud init
gcloud functions deploy ga4-conversions-to-b --region europe-west1 --entry-point main --trigger-http --runtime python39 --ingress-settings internal-only --timeout 540s