gcloud init
gcloud functions deploy nlp-api-test-260216 --region europe-west1 --entry-point main --trigger-http --runtime python39 --ingress-settings internal-only --timeout 540s