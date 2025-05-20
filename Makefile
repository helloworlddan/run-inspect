all: bootstrap

# Init should run once to create and persist some variable in .demoplate
init:
	@test -e .demoplate && exit
	@test -d .demoplate || mkdir .demoplate
	@read -p "Give me your LDAP [$$(whoami)]: " ldap && echo $${ldap:-$$(whoami)} > .demoplate/ldap
	@echo "admin@$$(<.demoplate/ldap).altostrat.com" > .demoplate/user
	@gcloud config set account $$(<.demoplate/user)
	@read -p "Select your Argolis billing account [$$(gcloud billing accounts list --format 'value(name)')]: " billing && echo $${billing:-$$(gcloud billing accounts list --format 'value(name)')} > .demoplate/billing_account
	@read -p "Select a region [europe-north1]: " region && echo $${region:-"europe-north1"} > .demoplate/region
	@test -w .demoplate/project || echo "$$(<.demoplate/ldap)-demo-$$(date -u '+%s')" > .demoplate/project

# Configure can be used to set `gcloud config` to _switch_ into the context of
# this demo.
configure: init
	@gcloud config set account $$(<.demoplate/user)
	@gcloud config set project $$(<.demoplate/project)
	@gcloud config set run/region $$(<.demoplate/region)
	@gcloud config set functions/region $$(<.demoplate/region)
	@gcloud config set deploy/region $$(<.demoplate/region)
	@gcloud config set artifacts/location $$(<.demoplate/region)
	@gcloud config set eventarc/location $$(<.demoplate/region)
	@gcloud config set memcache/region $$(<.demoplate/region)
	@gcloud config set redis/region $$(<.demoplate/region)

# Bootstrap should run once to create and bootstrap the demo project.
# The project number will be persisted in ./.demoplate/project_number.
bootstrap: init
	@printf "\n###### Begin bootstrapping $$(<.demoplate/project) ######\n\n"
	gcloud config set account $$(<.demoplate/user)
	# Create project
	gcloud projects create $$(<.demoplate/project) \
		--name "Demo $$(date -u '+%Y-%m-%d')" \
		--labels "purpose=demo,date=$$(date -u '+%Y-%m-%d')" \
		--quiet
	gcloud projects describe $$(<.demoplate/project) --format 'value(projectNumber)' > .demoplate/project_number
	gcloud config set project $$(<.demoplate/project)
	# Link billing account
	gcloud billing projects link $$(<.demoplate/project) --billing-account $$(<.demoplate/billing_account)
	# Enable services
	gcloud services enable {orgpolicy,compute,datastore,cloudbuild,run,eventarc,artifactregistry,aiplatform,memorystore,binaryauthorization}.googleapis.com
	# Override org-policies
	gcloud org-policies reset constraints/iam.allowedPolicyMemberDomains \
	  --project $$(<.demoplate/project)
	gcloud org-policies reset constraints/run.allowedBinaryAuthorizationPolicies \
	  --project $$(<.demoplate/project)
	# Set up service agents
	gcloud beta services identity create \
	  --service pubsub
	gcloud beta services identity create \
	  --service compute
	# Grant permissions for service accounts
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/bigquery.dataEditor \
	  --member "serviceAccount:service-$$(<.demoplate/project_number)@gcp-sa-pubsub.iam.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/bigquery.metadataViewer \
	  --member "serviceAccount:service-$$(<.demoplate/project_number)@gcp-sa-pubsub.iam.gserviceaccount.com"
	# Compute Engine Default SA
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/logging.logWriter \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/artifactregistry.admin \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/storage.admin \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/run.admin \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/cloudfunctions.developer \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/container.developer \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/secretmanager.admin \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/iam.serviceAccountUser \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/binaryauthorization.attestorsViewer \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/containeranalysis.notes.attacher \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	gcloud projects add-iam-policy-binding $$(<.demoplate/project) \
	  --role roles/aiplatform.user \
	  --member "serviceAccount:$$(<.demoplate/project_number)-compute@developer.gserviceaccount.com"
	# Create container registry
	gcloud artifacts repositories create gcr.io \
		--repository-format docker \
		--location us \
		--async
	gcloud artifacts repositories create us.gcr.io \
		--repository-format docker \
		--location us \
		--async
	gcloud artifacts repositories create eu.gcr.io \
		--repository-format docker \
		--location europe \
		--async
	gcloud artifacts repositories create asia.gcr.io \
		--repository-format docker \
		--location asia \
		--async
	# Run config
	@gcloud config set run/region $$(<.demoplate/region)
	@gcloud config set functions/region $$(<.demoplate/region)
	@gcloud config set deploy/region $$(<.demoplate/region)
	@gcloud config set artifacts/location $$(<.demoplate/region)
	@gcloud config set eventarc/location $$(<.demoplate/region)
	@gcloud config set memcache/region $$(<.demoplate/region)
	@gcloud config set redis/region $$(<.demoplate/region)
	# Done. Print URL.
	@printf "\n\t Project ready. Let's get to work: https://console.cloud.google.com/welcome?project=$$(<.demoplate/project) \n\n"

browse:
	@xdg-open "https://console.cloud.google.com/welcome?project=$$(<.demoplate/project)"

# Destroy shuts downs the project and removes local persisted
# ./.demoplate
destroy:
	@gcloud projects delete $$(<.demoplate/project)
	@rm -rf .demoplate

### Go targets
define GOSERVER
package main

import (
        "fmt"
        "net/http"
        "os"
)

func main() {
        http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
                fmt.Fprintf(w, "I am a web server!")
        })

        port := os.Getenv("PORT")
        if port == "" {
                port = "8080"
        }

        http.ListenAndServe(fmt.Sprintf(":%s", port), nil)
}
endef
export GOSERVER
define GODOCKERFILE 
FROM golang:1.23.2-bookworm as builder
WORKDIR /app/build/
COPY go.* /app/build/
RUN go mod download
COPY . /app/build/
RUN CGO_ENABLED=0 go build -v -o server

FROM gcr.io/distroless/static@sha256:72924583773eeeb9a6200e9f6dbfd95a27fbf25d39bfe7062c46d2654628f007
COPY --from=builder /app/build/server /app/server
CMD ["/app/server"]
endef
export GODOCKERFILE
define CLOUDBUILD
steps:
  - name: "gcr.io/cloud-builders/docker"
    args:
      [
        "build",
        "-t",
        "gcr.io/$$PROJECT_ID/demo",
        ".",
      ]
images: ["gcr.io/$$PROJECT_ID/demo"]
endef
export CLOUDBUILD
# Initialize go.mod and Dockerfile
go-init:
	@go mod init demo
	@echo "$$GOSERVER" > main.go

go-local:
	go run *.go

go-docker:
	@echo "$$GODOCKERFILE" > Dockerfile
	@echo "$$CLOUDBUILD" > cloudbuild.yaml

go-destroy:
	@rm -rf go.mod go.sum main.go Dockerfile cloudbuild.yaml

# Cloud Run targets
run-deploy-from-source:
	gcloud run deploy demo \
		--region $$(<.demoplate/region) \
		--allow-unauthenticated \
		--tag current \
		--source .

run-build:
	gcloud builds submit

run-deploy:
	gcloud run deploy demo \
		--region $$(<.demoplate/region) \
		--allow-unauthenticated \
		--tag current \
		--image "gcr.io/$$(<.demoplate/project)/demo"
	
run-load:
	hey \
		-n 50000 \
		-c 50 \
		--cpus 20 \
		$$(gcloud run services describe demo --format 'value(status.url)')

run-tags-clear:
	gcloud run services update-traffic demo \
		--clear-tags

run-deploy-next-no-traffic:
	gcloud run deploy demo \
		--region $$(<.demoplate/region) \
		--allow-unauthenticated \
		--image "gcr.io/$$(<.demoplate/project)/demo" \
		--tag next \
		--no-traffic

run-show:
	gcloud run services describe demo

run-shift-traffic-1:
	gcloud run services update-traffic demo \
		--to-tags next=1

run-shift-traffic-10:
	gcloud run services update-traffic demo \
		--to-tags next=10

run-shift-traffic-50:
	gcloud run services update-traffic demo \
		--to-tags next=50

run-shift-traffic-100:
	gcloud run services update-traffic demo \
		--to-latest

run-shift-rollback:
	gcloud run services update-traffic demo \
		--to-tags current=100

run-destroy:
	gcloud run services delete demo \
		--region $$(<.demoplate/region)

.ONESHELL: init
.PHONY: *
