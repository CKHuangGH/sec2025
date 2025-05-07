import jsonpickle
from enoslib.api import generate_inventory, run_ansible
import enoslib as en
import time
from datetime import datetime

en.set_config(ansible_forks=100)

# === Grid'5000 reservation settings ===
name = "devs1-management-1"
clusters = "ecotype"
site = "nantes"
duration = "12:00:00"
today = datetime.now().strftime("%Y-%m-%d")
reservation_time = today + " 17:01:00"
name_job = name + clusters
prod_network = en.G5kNetworkConf(type="prod", roles=["my_network"], site=site)

# === EnOSlib: Reserve physical nodes ===
conf = (
    en.G5kConf.from_settings(job_type="allow_classic_ssh", job_name=name_job, walltime=duration)
    .add_network_conf(prod_network)
    .add_network(
        id="not_linked_to_any_machine", type="slash_22", roles=["my_subnet"], site=site
    )
    .add_machine(
    roles=["role0"], cluster=clusters, nodes=3, primary_network=prod_network
    )
    .finalize()
)
provider = en.G5k(conf)
provider.destroy()