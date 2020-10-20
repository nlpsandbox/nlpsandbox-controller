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

    # Add docker.config file
    docker_image = args.docker_repository + "@" + args.docker_digest

    # These are the volumes that you want to mount onto your docker container
    #output_dir = os.path.join(os.getcwd(), "output")
    output_dir = os.getcwd()
    data_notes = args.data_notes

    # Look for if the container exists already, if so, reconnect
    print("checking for containers")
    container = None
    errors = None
    for cont in client.containers.list(all=True):
        if args.submissionid in cont.name:
            # Must remove container if the container wasn't killed properly
            if cont.status == "exited":
                cont.remove()
            else:
                container = cont
    # If the container doesn't exist, make sure to run the docker image
    if container is None:
        # Run as detached, logs will stream below
        print("starting service")
        # docker run -d -p 8081:8080 nlpsandbox/date-annotator-example:latest 
        # try:
        container = client.containers.run(docker_image,
                                          detach=True, # volumes=volumes,
                                          name=args.submissionid,
                                          # network_disabled=True,
                                          mem_limit='6g', stderr=True,
                                          ports={'8081': '8080'})
        # except docker.errors.APIError as err:
        #     remove_docker_container(args.submissionid)
        #     errors = str(err) + "\n"
    with open(data_notes, 'r') as notes_f:
        data_notes_dict = json.load(notes_f)

    # Run clinical notes on submitted API server
    response = requests.post("http://10.23.55.45:8081/api/v1/dates",
                             json=data_notes_dict['items'])
    results = response.json()
    with open("predictions.json", "w") as pred_f:
        json.dump(results, pred_f)

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
    remove_docker_image(docker_image)

    output_folder = os.listdir(output_dir)
    if "predictions.json" not in output_folder:
        raise Exception("Your API did not produce any results")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submissionid", required=True,
                        help="Submission Id")
    parser.add_argument("-p", "--docker_repository", required=True,
                        help="Docker Repository")
    parser.add_argument("-d", "--docker_digest", required=True,
                        help="Docker Digest")
    parser.add_argument("-i", "--data_notes", required=True,
                        help="Clinical data notes")
    parser.add_argument("-c", "--synapse_config", required=True,
                        help="credentials file")
    parser.add_argument("--parentid", required=True,
                        help="Parent Id of submitter directory")
    args = parser.parse_args()
    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login()

    main(syn, args)
