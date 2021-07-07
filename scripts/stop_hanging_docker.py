"""Stop and remove Docker containers of invalid submissions
Submissions that are cancelled or exceed time quota aren't
stopped and removed because docker kill does not send a
termination signal that can be caught"""
import signal
import time

import docker
import synapseclient


class GracefulKiller:
    """Kill job"""
    kill_now = False
    def __init__(self):
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)

    def exit_gracefully(self, signum, frame):
        self.kill_now = True


def stop_hanging_docker_submissions():
    """Stops hanging docker submissions"""
    syn = synapseclient.login()
    client = docker.from_env()
    running_containers = client.containers.list()
    for container in running_containers:
        try:
            status = syn.getSubmissionStatus(container.name)
            if status.status == "INVALID":
                print("stopping: " + container.name)
                container.stop()
                container.remove()
        except Exception:
            print("Not a synapse submission / unable to remove container")


if __name__ == "__main__":
    KILLER = GracefulKiller()
    while True:
        stop_hanging_docker_submissions()
        time.sleep(60)
        if KILLER.kill_now:
            break
    print("End of the program. I was killed gracefully :)")
