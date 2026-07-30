terraform {
  required_providers {
    # We will be working with linode and so will need the linode provider
    # in order to update DNS on linode, we'll need the linode provider.
    linode = {
      source = "linode/linode"
    }
  }

  backend "local" {
    path = "/container_shared/tfstate/linode-wireguard.tfstate"
  }

}

provider "linode" {
  token = var.LINODE_API_KEY
}
