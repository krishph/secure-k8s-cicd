"""List images from a rendered chart; PyYAML is a deployment-only dependency."""
import sys
import yaml


def images(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key in ("containers", "initContainers", "ephemeralContainers"):
                for container in item:
                    yield container["image"]
            else:
                yield from images(item)
    elif isinstance(value, list):
        for item in value:
            yield from images(item)


with open(sys.argv[1], encoding="utf-8") as stream:
    found = sorted(set(images(list(yaml.safe_load_all(stream)))))
if not found:
    sys.exit("No workload images found; refusing to deploy")
print("\n".join(found))
