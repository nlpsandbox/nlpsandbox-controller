"""Run training synthetic docker models"""
import argparse
import getpass
import json
import os
import random
import time

import docker
import synapseclient


def create_log_file(log_filename, log_text=None):
    """Create log file"""
    with open(log_filename, 'w') as log_file:
        if log_text is not None:
            if isinstance(log_text, bytes):
                log_text = log_text.decode("utf-8")
            log_file.write(log_text.encode("ascii", "ignore").decode("ascii"))
        else:
            log_file.write("No Logs")


def store_log_file(syn, log_filename, parentid, test=False):
    """Store log file"""
    statinfo = os.stat(log_filename)
    if statinfo.st_size > 0 and statinfo.st_size/1000.0 <= 50:
        ent = synapseclient.File(log_filename, parent=parentid)
        # Don't store if test
        if not test:
            try:
                syn.store(ent)
            except synapseclient.exceptions.SynapseHTTPError as err:
                print(err)


def remove_docker_container(container_name):
    """Remove docker container"""
    client = docker.from_env()
    try:
        cont = client.containers.get(container_name)
        cont.stop()
        cont.remove()
    except Exception:
        print("Unable to remove container")


def remove_docker_image(image_name):
    """Remove docker image"""
    client = docker.from_env()
    try:
        client.images.remove(image_name, force=True)
    except Exception:
        print("Unable to remove image")


def check_runtime(start, container, docker_image, quota):
    """Check runtime quota

    Args:
        start: Start time
        container: Running container
        docker_image: Docker image name
        quota: Time quota in seconds
    """
    timestamp = time.time()
    if timestamp - start > quota:
        container.stop()
        container.remove()
        remove_docker_image(docker_image)
        raise Exception(f"Your model has exceeded {quota/60} minutes")


def main(syn, args):
    """Run docker model"""
    client = docker.from_env()

    print(getpass.getuser())

    # These are the volumes that you want to mount onto your docker container
    output_dir = os.getcwd()
    data_notes = args.data_notes

    # print("mounting volumes")
    # These are the locations on the docker that you want your mounted
    # volumes to be + permissions in docker (ro, rw)
    # It has to be in this format '/output:rw'
    # mounted_volumes = {output_dir: '/output:rw'}

    # # All mounted volumes here in a list
    # all_volumes = [output_dir]
    # # Mount volumes
    # volumes = {}
    # for vol in all_volumes:
    #     volumes[vol] = {'bind': mounted_volumes[vol].split(":")[0],
    #                     'mode': mounted_volumes[vol].split(":")[1]}
    print("Get submission container")
    submissionid = args.submissionid
    container = client.containers.get(submissionid)

    # docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name
    container_ip = container.attrs['NetworkSettings'][
        'Networks'
    ]['submission']['IPAddress']

    with open(data_notes, 'r') as notes_f:
        data_notes_dict = json.load(notes_f)
    api_url_map = {
        'nlpsandbox:date-annotator': "textDateAnnotations",
        'nlpsandbox:person-name-annotator': "textPersonNameAnnotations",
        'nlpsandbox:physical-address-annotator': "textPhysicalAddressAnnotations"
    }

    all_annotations = []
    # Get annotation start time
    start = time.time()
    for note in data_notes_dict:
        # Check that runtime is less than 2 hours (7200 seconds)
        check_runtime(start, container, container.image, 7200)
        # noteid = note.pop("identifier")
        exec_cmd = [
            #"curl", "-o", "/output/annotations.json", "-X", "POST",
            "curl", "-s", "-X", "POST",
            f"http://{container_ip}:8080/api/v1/{api_url_map[args.annotator_type]}", "-H",
            "accept: application/json",
            "-H", "Content-Type: application/json", "-d",
            json.dumps({"note": note})
        ]
        curl_name = f"{args.submissionid}_curl_{random.randint(10, 1000)}"
        annotate_note = client.containers.run(
            "curlimages/curl:7.73.0", exec_cmd,
            # volumes=volumes,
            name=curl_name,
            network="submission", stderr=True
            # auto_remove=True
        )
        annotations = json.loads(annotate_note.decode("utf-8"))
        remove_docker_container(curl_name)

        # with open("annotations.json", "r") as note_f:
        #     annotations = json.load(note_f)

        annotations['annotationSource'] = {
            "resourceSource": {
                "name": note['note_name']
            }
        }
        all_annotations.append(annotations)

    with open("predictions.json", "w") as pred_f:
        json.dump(all_annotations, pred_f)

    # print("creating logfile")
    # # Create the logfile
    # log_filename = args.submissionid + "_log.txt"
    # # Open log file first
    # open(log_filename, 'w').close()

    # # If the container doesn't exist, there are no logs to write out and
    # # no container to remove
    # if container is not None:
    #     # Check if container is still running
    #     while container in client.containers.list():
    #         log_text = container.logs()
    #         create_log_file(log_filename, log_text=log_text)
    #         store_log_file(syn, log_filename, args.parentid)
    #         time.sleep(60)
    #     # Must run again to make sure all the logs are captured
    #     log_text = container.logs()
    #     create_log_file(log_filename, log_text=log_text)
    #     store_log_file(syn, log_filename, args.parentid)
    #     # Remove container and image after being done
    #     container.remove()

    # statinfo = os.stat(log_filename)

    # if statinfo.st_size == 0:
    #     create_log_file(log_filename, log_text=errors)
    #     store_log_file(syn, log_filename, args.parentid)

    print("finished")
    # Try to remove the image
    remove_docker_container(args.submissionid)
    remove_docker_image(container.image)

    output_folder = os.listdir(output_dir)
    if "predictions.json" not in output_folder:
        raise Exception("Your API did not produce any results")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submissionid", required=True,
                        help="Submission Id", type=str)
    parser.add_argument("-i", "--data_notes", required=True,
                        help="Clinical data notes")
    parser.add_argument("-c", "--synapse_config", required=True,
                        help="credentials file")
    parser.add_argument("-a", "--annotator_type", required=True,
                        help="Annotation Type")
    args = parser.parse_args()
    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login()

    main(syn, args)
