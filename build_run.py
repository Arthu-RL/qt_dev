import argparse
import subprocess as sp
import logging as log

log.basicConfig(level=log.INFO, format='%(levelname)s: %(message)s')

def build(image: str) -> None:
    build_command: str = f"docker build -t {image} -f Dockerfile ."

    log.info(f"Running build command: {build_command}")

    try:
        result = sp.run(build_command, shell=True, check=True, capture_output=True, text=True)
        log.info(f"Build output:\n{result.stderr}")
    except sp.CalledProcessError as e:
        log.error(f"Build failed with error:\n{e.stderr}")
        exit(1)

def run(project_path: str, image: str, container_name: str) -> None:
    run_command: str = f"""
        docker rm -f {container_name} && \
        docker run --gpus all -d --name {container_name} \
            --device /dev/dri:/dev/dri \
            -e DISPLAY=$DISPLAY \
            -v /tmp/.X11-unix:/tmp/.X11-unix \
            -v {project_path}:/workspace \
            -w /workspace \
            {image}
    """

    log.info(f"Run command:\n{run_command}")

    try:
        result = sp.run(run_command, shell=True, check=True, capture_output=True, text=True)
        log.info(f"Run output:\n{result.stdout}")
    except sp.CalledProcessError as e:
        log.error(f"Run failed with error:\n{e.stderr}")
        exit(1)

if __name__ == '__main__':
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description="Build Vulkan dev image")

    parser.add_argument('--run', dest='run', action='store_true', help='Run container instead of building', required=False)
    parser.add_argument('-p', '--project_path', dest='project_path', type=str, help='Path to the project', default='$HOME/dev')
    parser.add_argument('-t', '--image_tag', dest='image_tag', type=str, help='Tag of the dev image', default='')
    parser.add_argument('-i', '--image_name', dest='image_name', type=str, help='Name of the dev image', default='vulkan_dev')
    parser.add_argument('-c', '--container_name', dest='container_name', type=str, help='Name of the dev container', default='vulkan_dev')

    args: argparse.Namespace = parser.parse_args()

    image: str = f"{args.image_tag}/{args.image_name}"

    if args.run:
        run(project_path=args.project_path, image=image, container_name=args.container_name)
    else:
        build(image=image)
