import jsonpickle
import enoslib as en
from enoslib.infra.enos_vmong5k.configuration import Configuration
from enoslib.infra.enos_vmong5k.provider import VMonG5k

en.set_config(ansible_forks=100)

# === Load saved role and network information ===
with open("reserved_management.json", "r") as f:
    roles = jsonpickle.decode(f.read())

with open("reserved_management_networks.json", "r") as f:
    networks = jsonpickle.decode(f.read())

# === VM configuration (must match original deployment) ===
clusters = "ecotype"  # Update if you used a different cluster
subnet = networks["my_subnet"]
mac = list(subnet[0].free_macs)[0]

virt_conf = (
    en.VMonG5kConf.from_settings(image="/home/chuang/images/debian31032025.qcow2")
    .add_machine(
        roles=["cp"],
        number=1,
        cluster=clusters,  # REQUIRED for destroy()
        undercloud=roles["role0"],
        flavour_desc={"core": 16, "mem": 32768},
        macs=[mac],
    ).finalize()
)

# === Destroy the virtual machine(s) ===
provider = VMonG5k(virt_conf)
provider.destroy()

print("VM successfully deleted.")
