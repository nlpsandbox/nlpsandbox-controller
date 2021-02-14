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

TBA

### Start the Orchestrator

TBA

### Start the example Data Annotator

TBA

## Orchestrator workflow template

This repository will serve as a template for the `CWL` workflow and tools required to set up a `model-to-data` challenge infrastructure.

For more information about the tools, please head to [ChallengeWorkflowTemplates](https://github.com/Sage-Bionetworks/ChallengeWorkflowTemplates)


## Requirements
* `pip3 install cwltool`
* A synapse account / configuration file.  Learn more [here](https://docs.synapse.org/articles/client_configuration.html#for-developers)
* A Synapse submission to a queue.  Learn more [here](https://docs.synapse.org/articles/evaluation_queues.html#submissions)

## What to edit

* **workflow.cwl**
  - update L53 (`valueFrom: "syn18081597"`) to the Synapse ID where your workflow is located - **required**
  - remove L82-83 (`id: errors_only...`) if sending a "Submission valid!" email is also wanted (default action is to only send an email if invalid reasons are found) - optional
  - update L135 (`default: []`) with score annotations that are meant to remain prviate from the participant - optional

*  **validate.cwl**
   - update L11 (`dockerPull: python:3.7`) if you are not using a Python script to validate
   - update the lines of code after `entry: |` with your own validation code
      - NOTE: expected annotations to write out are `prediction_file_status` and `prediction_file_errors` (see [ChallengeWorkflowTemplates](https://github.com/Sage-Bionetworks/ChallengeWorkflowTemplates#validation-validatecwl) for more information.)

* **score.cwl**
  - update L11 (`dockerPull: python:3.7`) if you are not using a Python script to score
  - update the lines of code after `entry: |` with your own scoring code


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
