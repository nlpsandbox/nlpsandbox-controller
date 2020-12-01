"""Run training synthetic docker models"""
import argparse
import getpass
import json
import os
import time

import docker
import requests
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


def main(syn, args):
    """Run docker model"""
    client = docker.from_env()

    print(getpass.getuser())

    # These are the volumes that you want to mount onto your docker container
    output_dir = os.getcwd()
    data_notes = args.data_notes
    print("mounting volumes")
    # These are the locations on the docker that you want your mounted
    # volumes to be + permissions in docker (ro, rw)
    # It has to be in this format '/output:rw'
    mounted_volumes = {output_dir: '/output:rw'}

    # All mounted volumes here in a list
    all_volumes = [output_dir]
    # Mount volumes
    volumes = {}
    for vol in all_volumes:
        volumes[vol] = {'bind': mounted_volumes[vol].split(":")[0],
                        'mode': mounted_volumes[vol].split(":")[1]}

    print("Get submission container")
    container = client.containers.get(args.submissionid)

    # docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name
    container_ip = container.attrs['NetworkSettings'][
        'Networks'
    ]['submission']['IPAddress']

    with open(data_notes, 'r') as notes_f:
        data_notes_dict = json.load(notes_f)
    # TODO: This will have to map to evaluation queue
    api_url_map = {
        'date': "textDateAnnotations",
        'person': "textPersonNameAnnotations",
        'location': "textPhysicalAddressAnnotations"
    }

    all_annotations = []
    for note in data_notes_dict:
        noteid = note.pop("id")
        exec_cmd = [
            "curl", "-o", "/output/annotations.json", "-X", "POST",
            f"http://{container_ip}:8080/api/v1/{api_url_map['date']}", "-H",
            "accept: application/json",
            "-H", "Content-Type: application/json", "-d",
            json.dumps({"note": note})
        ]
        client.containers.run("curlimages/curl:7.73.0", exec_cmd,
                              volumes=volumes,
                              name=f"{args.submissionid}_curl",
                              network="submission", stderr=True,
                              auto_remove=True)

        with open("annotations.json", "r") as note_f:
            annotations = json.load(note_f)
        # TODO: update this to use note_name
        annotations['annotationSource'] = {"resourceSource": noteid}
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
                        help="Submission Id")
    parser.add_argument("-i", "--data_notes", required=True,
                        help="Clinical data notes")
    parser.add_argument("-c", "--synapse_config", required=True,
                        help="credentials file")
    args = parser.parse_args()
    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login()

    main(syn, args)