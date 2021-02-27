"""Pushes dataset for validation of reproducibility"""
import json
import sys

import synapseclient

import datanode
import datanode.apis
import datanode.models
from datanode.rest import ApiException
import nlpsandboxclient.utils

syn = synapseclient.login()
host = ""
if host == "":
    raise ValueError("Must set host to be data node URL")
configuration = datanode.Configuration(
    host=host
)

dataset_id = '2014-i2b2-20201203-subset'
fhir_store_id = 'evaluation'
annotation_store_id = 'goldstandard'
# Get evaluation-patient-bundles.json
json_ent = syn.get("syn23593068")
json_filename = json_ent.path


def get_or_create_resource(get_func, create_func, *args, **kwargs):
    """Get or create a data node resource
    
    Args:
        get_func: Function to get resource
        create_func: Function to create resource
        *args: Positional arguments for the get/create functions
        **kwargs: Keyword arguments for the get/create functions

    Returns:
        resource object

    """
    try:
        # get the dataset
        resource = get_func(*args)
    except ApiException as e:
        if e.status == 404:
            # create dataset if not found
            try:
                resource = create_func(
                    *args,
                    **kwargs
                )
            except ApiException as e:
                print(f"Exception when calling {create_func}: {e}\n")
                sys.exit(-1)
        else:
            print(f"Exception when calling {get_func}: {e}\n")
            sys.exit(-1)
    return resource


with datanode.ApiClient(configuration) as api_client:
    dataset_api = datanode.apis.DatasetApi(api_client)
    fhir_store_api = datanode.apis.FhirStoreApi(api_client)
    annotation_store_api = datanode.apis.AnnotationStoreApi(api_client)
    patient_api = datanode.apis.PatientApi(api_client)
    note_api = datanode.apis.NoteApi(api_client)
    annotation_api = datanode.apis.AnnotationApi(api_client)

    # Get or create Dataset
    dataset = get_or_create_resource(
        dataset_api.get_dataset,
        dataset_api.create_dataset,
        dataset_id,
        body={}
    )

    # Get or create FHIR store
    fhir_store = get_or_create_resource(
        fhir_store_api.get_fhir_store,
        fhir_store_api.create_fhir_store,
        dataset_id,
        fhir_store_id,
        body={}
    )

    annotation_store = get_or_create_resource(
        annotation_store_api.get_annotation_store,
        annotation_store_api.create_annotation_store,
        dataset_id,
        annotation_store_id,
        body={}
    )

    print(f"dataset: {dataset}")
    print(f"fhir_store: {fhir_store}")
    print(f"annotation_store: {annotation_store}")

    with open(json_filename) as f:
        data = json.load(f)
        patient_bundles = data['patient_bundles']
        # patient_bundles = patient_bundles[:1]

    for patient_bundle in patient_bundles:
        # Create or get a FHIR Patient
        patient = nlpsandboxclient.utils.change_keys(
            patient_bundle['patient'],
            nlpsandboxclient.utils.camelcase_to_snakecase
        )
        patient_id = patient.pop("identifier")
        # Only notes and annotations from these 3 patients
        if patient_id not in ['110', '111', '112']:
            continue
        patient = get_or_create_resource(
            patient_api.get_patient,
            patient_api.create_patient,
            dataset_id,
            fhir_store_id,
            patient_id,
            patient_create_request=patient
        )
        patient_id = str(
            patient.identifier if patient.get("name") is None
            else patient.name.to_str().split("/")[-1]
        )
        print(f"patient: {patient_id}")

        # Create the Note and Annotation objects linked to the patient
        note_bundles = patient_bundle['note_bundles']
        # note_bundles = note_bundles[:1]

        for note_bundle in note_bundles:
            # Determine note Id since noteId isn't part of the 'note'
            annotation = note_bundle['annotation']
            annotations_cols = ['textDateAnnotations',
                                'textPhysicalAddressAnnotations',
                                'textPersonNameAnnotations']
            note_ids = set()
            for col in annotations_cols:
                for annot in annotation[col]:
                    note_ids.add(annot['noteId'])
            assert len(note_ids) == 1, "Must only have one noteId"
            note_id = list(note_ids)[0]

            # Create Note
            note = nlpsandboxclient.utils.change_keys(
                note_bundle['note'],
                nlpsandboxclient.utils.camelcase_to_snakecase
            )
            note['patient_id'] = patient_id
            note = get_or_create_resource(
                note_api.get_note,
                note_api.create_note,
                dataset_id,
                fhir_store_id,
                note_id,
                note_create_request=note
            )
            # Create annotation
            annotation['annotationSource']['resourceSource']['name'] = \
                "{fhir_store_name}/fhir/Note/{note_id}".format(
                    fhir_store_name=fhir_store.name,
                    note_id=note_id
                )
            new_annotation = nlpsandboxclient.utils.change_keys(
                annotation,
                nlpsandboxclient.utils.camelcase_to_snakecase
            )
            annotation = get_or_create_resource(
                annotation_api.get_annotation,
                annotation_api.create_annotation,
                dataset_id,
                annotation_store_id,
                note_id,
                annotation_create_request=new_annotation
            )
