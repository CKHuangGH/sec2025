from enoslib.api import generate_inventory,run_ansible
from enoslib.infra.enos_vmong5k.provider import VMonG5k
from enoslib.infra.enos_vmong5k.configuration import Configuration
import time
import enoslib as en
from datetime import datetime

en.set_config(ansible_forks=100)

name = "s1-member-1-now"

clusters = "ecotype"

site = "nantes"

master_nodes = []

duration = "12:00:00"

prod_network = en.G5kNetworkConf(type="prod", roles=["my_network"], site=site)

today = datetime.now().strftime("%Y-%m-%d")

reservation_time = today + " 17:01:00"

name_job = name + clusters

role_name = "cluster" + str(clusters)

conf = (
    en.G5kConf.from_settings(job_type="allow_classic_ssh", job_name=name_job, walltime=duration)
    .add_network_conf(prod_network)
    .add_network(
        id="not_linked_to_any_machine", type="slash_22", roles=["my_subnet"], site=site
    )
    .add_machine(
    roles=["server"], cluster=clusters, nodes=2, primary_network=prod_network, servers=[f"ecotype-{i}.nantes.grid5000.fr" for i in range(2, 47)]
    )
    .finalize()
)
provider = en.G5k(conf)
provider.destroy()