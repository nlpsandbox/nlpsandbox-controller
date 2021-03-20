# NLP Sandbox Controller

[![GitHub Release](https://img.shields.io/github/release/nlpsandbox/nlpsandbox-controller.svg?include_prereleases&color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/nlpsandbox/nlpsandbox-controller/releases)
[![GitHub License](https://img.shields.io/github/license/nlpsandbox/nlpsandbox-controller.svg?color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/nlpsandbox/nlpsandbox-controller/blob/main/LICENSE)
[![Discord](https://img.shields.io/discord/770484164393828373.svg?color=94398d&labelColor=555555&logoColor=ffffff&style=for-the-badge&label=Discord&logo=discord)](https://discord.gg/Zb4ymtF "Realtime support / chat with the community and the team")

## Introduction

This document describes how to deploy the infrastructure needed to evaluate the
performance of an NLP Tool submitted to the NLP Sandbox.

One of the feature of the NLP Sandbox is the ability for NLP developers to
submit their NLP Tool once and then have it evaluated on multiple Data Hosting
Sites.

## Submission workflow

The figure below represents how the infrastructure deployed on a Data Hosting
Site evaluates the performance of a tool submitted by a developer to the NLP
Sandbox.

![Infrastructure overview](pictures/infrastructure_overview.png)

The submission workflow is composed of these steps:

1.  An NLP Developer submits an NLP tool for evaluation using the NLP Sandbox
    web client or command line interface (CLI). The submission is added to one of
    the submission queues of the NLP Sandbox depending on the NLP Task selected
    by the NLP Developer.
1.  The *NLP Sandbox Workflow Orchestrator* query one or more submissions queues
    for submissions to process. The Orchestrator that runs on a Data Hosting Site
    only query submissions that it can evaluate based on the type of data stored
    in the Data Node(s) available (XXX: clarify the case where there are multiple
    Data Nodes).
1.  If there is a `RECEIVED` submission, the Orchestrator will start running a
    workflow with the submission as its input.  The steps to the workflow is outlined
    in [workflow.cwl](workflow.cwl).
    1.  Starts the NLP Tool (web service) to evaluate
    1.  Queries N clinical notes from the Data Node.
    1.  Sends the N clinical notes to the NLP Tool and receives the
        predictions.
    1.  Repeats Steps 4 and 5 until all the clinical notes included
        in a given dataset have been processed by the NLP Tool.
    1.  Stops the NLP Tool.
    1.  Queries the gold standard from the Data Node.
    1.  Evaluates the performance of the predictions by comparing
        them to the gold standard.
    1.  Sends the performance measured to the NLP Sandbox backend server.
1. The NLP Developer and the community review the performance of the NLP Tool.

## Deploy the infrastructure on Data Hosting Site

To be a NLP sandbox data hosting site, the site must be able to host 4 main technology stacks via Docker. Here are the requirements : 

- Docker : ver 
- Docker-compose : ver 1.28.5 or higher
- Data Node
- SynapseWorkflowOrchestrator
- ELK (Elasticsearch, Logstash, Kibana)
- NLP Tools (E.g. Date-Annotators)

### Data Node

1. Clone and start the data node.  This step should already be done by the cloudformation script for Sage Bionetworks.
    ```bash
    git clone https://github.com/nlpsandbox/data-node.git
    cd data-node
    cp .env.example .env
    docker-compose up -d
    ```
1. Push data into the data-node.
    ```bash
    # set up conda or pipenv environment
    pip install nlpsandbox-client
    # Pushes challenge data
    python scripts/push_challenge_data.py
    # Pushes small subset of data
    python scripts/push_small_dataset.py
    ```

### SynapseWorkflowOrchestrator

1. Obtain/Create a Service Account (TBD)
1. Clone the repository
    ```bash
    git clone https://github.com/Sage-Bionetworks/SynapseWorkflowOrchestrator.git
    cd SynapseWorkflowOrchestrator
    ```
1. Copy the example template `cp .envTemplate .env` and configure. Sage Bionetworks uses the service account `nlp-sandbox-bot` and these `EVALUTION_TEMPLATES`, but these will be different per data hosting site.
    ```text
    SYNAPSE_USERNAME=nlp-sandbox-bot  # The data hosting site will have to created their own synapse service account.
    SYNAPSE_PASSWORD=
    EVALUATION_TEMPLATES={"queueid": "synid"}  # This mapping will be provided to the site by Sage Bionetworks.
    WORKFLOW_OUTPUT_ROOT_ENTITY_ID=synid  # This value will be provided to the site by Sage Bionetworks.
    # WES_ENDPOINT=http://localhost:8082/ga4gh/wes/v1  # This needs to be commented
    ```
1. Start the orchestrator
    ```
    docker-compose up -d
    ```
1. _Optional_: Start [portainerer](https://documentation.portainer.io/v2.0/deploy/ceinstalldocker/)  This is an open source tool for managing container-based software applications (e.g. provides a GUI to view Docker images and running containers).
    ```
    docker volume create portainer_data
    docker run -d -p 8000:8000 -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
    ```
1. _If hosting ELK on a different instance from running submissions_:  Add the following section to the `docker-compose.yaml`.  The `ROUTE_URIS` will be different from the `Sage Bionetworks` site.
    ```yaml
    logspout:
      image: bekt/logspout-logstash
      restart: on-failure
      environment:
        - ROUTE_URIS=logstash://10.23.60.253:5000  # Only for Sage Bionetworks
        - LOGSTASH_TAGS=docker-elk
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
    ```
    Where `10.23.60.253` is the IP Address of your external ELK Server


### Capturing Docker Logs

A solution to track Docker container logs are a **requirement** to be a data hosting site.  The reason for this is because the tool services submitted by participants are hosted as Docker containers and if there are issues with the service, the logs will have to be returned to participants.  We suggest using ELK stack (instructions below), but there are plenty of other methods you can use to [capture Docker logs](https://docs.docker.com/config/containers/logging/configure/).

1. Clone the repository
    ```
    git clone https://github.com/nlpsandbox/docker-elk.git
    cd docker-elk
    docker-compose up -d
    ```
1. Only use the free version of ELK. This can be configured [here](https://www.elastic.co/guide/en/kibana/7.11/managing-licenses.html)
1. Change the `elastic passwords` in each of these locations:
    - `docker-compose.yml`
    - `kibana/config/kibana.yml`
    - `logstash/config/logstash.yml`
    - `elasticsearch/config/elasticsearch.yml`
1. _Running everything all the compoenents on one machine_:  If you are running everything on one machine, you can do:
    ```
    docker-compose -f docker-compose.yml -f extensions/logspout/logspout-compose.yml up
    ```
    This will automatically start logspout for you and you won't have to add it to the `SynapseWorkflowOrchestrator`


### Example Date Annotator

Clone and start the date annotator.
This should also be done by the cloudformation template.
```bash
git clone https://github.com/nlpsandbox/date-annotator-example.git
cd date-annotator-example
docker-compose up -d
```

## SAGE BIONETWORKS ONLY

### Orchestrator workflow

This repository will host the `CWL` workflow and tools required to set up the `model-to-data` challenge infrastructure for `NLP Sandbox`

For more information about the tools, please head to [ChallengeWorkflowTemplates](https://github.com/Sage-Bionetworks/ChallengeWorkflowTemplates)


### Requirements
* `pip3 install cwltool`
* A synapse account / configuration file.  Learn more [here](https://docs.synapse.org/articles/client_configuration.html#for-developers)
* A Synapse submission to a queue.  Learn more [here](https://docs.synapse.org/articles/evaluation_queues.html#submissions)

### What to edit

* **workflow.cwl**
    If there are updates to the api version or dataset version, the workflow inputs
    have to be editted
    ```yaml
    - id: dataset_name
        type: string
        default: "2014-i2b2"  # change this
    - id: dataset_version
        type: string
        default: "20201203" # change this
    - id: api_version
        type: string
        default: "1.0.1" # change this
    ```

### Testing the workflow locally

```bash
cwltool workflow.cwl --submissionId 12345 \
                      --adminUploadSynId syn12345 \
                      --submitterUploadSynId syn12345 \
                      --workflowSynapseId syn12345 \
                      --synaspeConfig ~/.synapseConfig
```
where:
* `submissionId` - ID of the Synapse submission to process
* `adminUploadSynId` - ID of a Synapse folder accessible only to the submission queue administrator
* `submitterUploadSynId` - ID of a Synapse folder accessible to the submitter
* `workflowSynapseId` - ID of the Synapse entity containing a reference to the workflow file(s)
* `synapseConfig` - filepath to your Synapse credentials
