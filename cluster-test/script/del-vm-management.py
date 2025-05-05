import jsonpickle
import enoslib as en
from enoslib.api import generate_inventory, run_ansible
from enoslib.infra.enos_vmong5k.configuration import Configuration
from enoslib.infra.enos_vmong5k.provider import VMonG5k
import time

en.set_config(ansible_forks=100)

# === Load saved reservation info ===
with open("reserved_management.json", "r") as f:
    roles = jsonpickle.decode(f.read())

with open("reserved_management_networks.json", "r") as f:
    networks = jsonpickle.decode(f.read())

# === VM deployment configuration ===
subnet = networks["my_subnet"]
mac = list(subnet[0].free_macs)[0]

virt_conf = (
    en.VMonG5kConf.from_settings(image="/home/chuang/images/debian31032025.qcow2")
    .add_machine(
        roles=["cp"],
        number=1,
        cluster="ecotype",
        undercloud=roles["role0"],
        flavour_desc={"core": 16, "mem": 32768},
        macs=[mac],
    ).finalize()
)

# === Start VMs ===

provider = VMonG5k(virt_conf)
provider.destroy()