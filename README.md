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
2.  The *NLP Sandbox Workflow Orchestrator* query one or more submissions queues
    for submissions to process. The Orchestrator that runs on a Data Hosting Site
    only query submissions that it can evaluate based on the type of data stored
    in the Data Node(s) available (XXX: clarify the case where there are multiple
    Data Nodes).
3.  The Orchestrator starts the NLP Tool (web service) to evaluate
4.  The Orchestrator queries N clinical notes from the Data Node.
5.  The Orchestrator sends the N clinical notes to the NLP Tool and receives the
    predictions.
6.  The Orchestrator repeats Steps 4 and 5 until all the clinical notes included
    in a given dataset have been processed by the NLP Tool.
7.  The Orchestrator stops the NLP Tool.
8.  The Orchestrator queries the gold standard from the Data Node.
9.  The Orchestrator evaluates the performance of the predictions by comparing
    them to the gold standard.
10. Sends the performance measured to the NLP Sandbox backend server.
11. The NLP Developer and the community review the performance of the NLP Tool.

## Deploy the infrastructure on Sage Data Hosting Site

### Start the 2014 i2b2 Data Node

1. Clone and start the data node.  This step should already be done by the
   cloudformation script.
    ```bash
    git clone https://github.com/nlpsandbox/data-node.git
    cd data-node
    cp .env.example .env
    docker-compose up -d
    ```
2. Push data into the data-node.
    ```bash
    # set up conda or pipenv environment
    pip install nlpsandbox-client
    # Pushes challenge data
    python scripts/push_challenge_data.py
    # Pushes small subset of data
    python scripts/push_small_dataset.py
    ```

### Start the Orchestrator

1. Clone the repository
    ```bash
    git clone https://github.com/Sage-Bionetworks/SynapseWorkflowOrchestrator.git
    cd SynapseWorkflowOrchestrator
    ```
2. Add to the `docker-compose.yaml`:
    ```yaml
    logspout:
      image: bekt/logspout-logstash
      restart: on-failure
      environment:
        - ROUTE_URIS=logstash://10.23.60.253:5000
        - LOGSTASH_TAGS=docker-elk
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
    ```
3. Copy the example template `cp .envTemplate .env` and configure
    ```text
    SYNAPSE_USERNAME=nlp-sandbox-bot
    SYNAPSE_PASSWORD=
    EVALUATION_TEMPLATES={"9614654": "syn23626300", "9614684": "syn23626300", "9614685": "syn23626300", "9614658": "syn23633112", "9614652": "syn23633112", "9614657": "syn23633112"}
    ```
4. Start the orchestrator
    ```
    docker-compose up -d
    ```
5. Start [portainerer](https://documentation.portainer.io/v2.0/deploy/ceinstalldocker/)
    ```
    docker volume create portainer_data
    docker run -d -p 8000:8000 -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
    ```

### Start the example Date Annotator

Clone and start the date annotator.
This should also be done by the cloudformation template.
```bash
git clone https://github.com/nlpsandbox/date-annotator-example.git
cd date-annotator-example
cp .env.example .env
docker-compose up -d
```


## Orchestrator workflow template

This repository will serve as a template for the `CWL` workflow and tools required to set up a `model-to-data` challenge infrastructure.

For more information about the tools, please head to [ChallengeWorkflowTemplates](https://github.com/Sage-Bionetworks/ChallengeWorkflowTemplates)


## Requirements
* `pip3 install cwltool`
* A synapse account / configuration file.  Learn more [here](https://docs.synapse.org/articles/client_configuration.html#for-developers)
* A Synapse submission to a queue.  Learn more [here](https://docs.synapse.org/articles/evaluation_queues.html#submissions)

## What to edit

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

## Testing the workflow locally

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
