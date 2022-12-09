terraform {
  required_providers {
    test = {
      source = "terraform.io/builtin/test"
    }
    aviatrix = {
      source = "aviatrixsystems/aviatrix"
    }
  }
}

module "transit_non_ha_azure" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.4.0"

  cloud                  = "azure"
  name                   = "transit-non-ha-azure"
  region                 = "West Europe"
  cidr                   = "10.1.0.0/23"
  account                = "Azure"
  ha_gw                  = false
  enable_transit_firenet = true
}

module "mc_firenet_non_ha_azure" {
  source = "../.."

  transit_module = module.transit_non_ha_azure
  firewall_image = "Fortinet FortiGate (PAYG) Next-Generation Firewall"
  egress_enabled = true
}

variable "custom_fw_names" {
  type = list(string)
  default = [
    "az1-fw1",
    "az1-fw2",
    "az2-fw1",
    "az2-fw2",
  ]
}

module "transit_ha_azure" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.4.0"

  cloud                  = "azure"
  name                   = "transit-ha-azure"
  region                 = "West Europe"
  cidr                   = "10.2.0.0/23"
  account                = "Azure"
  enable_transit_firenet = true
}

module "mc_firenet_ha_azure" {
  source = "../.."

  transit_module = module.transit_ha_azure
  firewall_image = "Fortinet FortiGate (PAYG) Next-Generation Firewall"
  egress_enabled = true
  fw_amount      = 4
}


resource "test_assertions" "public_ip_non_ha" {
  component = "public_ip_non_ha_azure"

  check "fw_public_ip" {
    description = "NGFW has public IP"
    condition   = can(cidrnetmask("${module.mc_firenet_non_ha_azure.aviatrix_firewall_instance[0].public_ip}/32"))
  }
}

resource "test_assertions" "public_ip_ha" {
  component = "public_ip_ha_azure"

  check "fw1_public_ip" {
    description = "NGFW 1 has valid IP"
    condition   = can(cidrnetmask("${module.mc_firenet_ha_azure.aviatrix_firewall_instance[0].public_ip}/32"))
  }

  check "fw2_public_ip" {
    description = "NGFW 2 has valid IP"
    condition   = can(cidrnetmask("${module.mc_firenet_ha_azure.aviatrix_firewall_instance[1].public_ip}/32"))
  }

  check "fw3_public_ip" {
    description = "NGFW 3 has valid IP"
    condition   = can(cidrnetmask("${module.mc_firenet_ha_azure.aviatrix_firewall_instance[2].public_ip}/32"))
  }

  check "fw4_public_ip" {
    description = "NGFW 4 has valid IP"
    condition   = can(cidrnetmask("${module.mc_firenet_ha_azure.aviatrix_firewall_instance[3].public_ip}/32"))
  }
}

resource "test_assertions" "egress_subnet_allocation_non_ha" {
  component = "egress_subnet_allocation_non_ha_azure"

  equal "egress_subnet_allocation_ngfw" {
    description = "Check NGFW is in correct egress subnet."
    got         = module.mc_firenet_non_ha_azure.aviatrix_firewall_instance[0].egress_subnet
    want        = module.transit_non_ha_azure.vpc.public_subnets[1].cidr
  }
}

resource "test_assertions" "egress_subnet_allocation_ha" {
  component = "egress_subnet_allocation_ha_azure"

  equal "egress_subnet_allocation_ngfw1" {
    description = "Check NGFW 1 is in correct egress subnet."
    got         = module.mc_firenet_ha_azure.aviatrix_firewall_instance[0].egress_subnet
    want        = module.transit_ha_azure.vpc.public_subnets[0].cidr
  }

  equal "egress_subnet_allocation_ngfw2" {
    description = "Check NGFW 2 is in correct egress subnet."
    got         = module.mc_firenet_ha_azure.aviatrix_firewall_instance[1].egress_subnet
    want        = module.transit_ha_azure.vpc.public_subnets[0].cidr
  }

  equal "egress_subnet_allocation_ngfw3" {
    description = "Check NGFW 3 is in correct egress subnet."
    got         = module.mc_firenet_ha_azure.aviatrix_firewall_instance[2].egress_subnet
    want        = module.transit_ha_azure.vpc.public_subnets[1].cidr
  }

  equal "egress_subnet_allocation_ngfw4" {
    description = "Check NGFW 4 is in correct egress subnet."
    got         = module.mc_firenet_ha_azure.aviatrix_firewall_instance[3].egress_subnet
    want        = module.transit_ha_azure.vpc.public_subnets[1].cidr
  }
}

resource "test_assertions" "custom_fw_name_ha" {
  component = "custom_fw_name_ha_azure"

  equal "custom_fw_name_ngfw1" {
    description = "Check NGFW 1 custom FW name."
    got         = module.mc_firenet_ha_azure.aviatrix_firewall_instance[0].firewall_name
    want        = var.custom_fw_names[0]
  }

  equal "custom_fw_name_ngfw2" {
    description = "Check NGFW 2 custom FW name."
    got         = module.mc_firenet_ha_azure.aviatrix_firewall_instance[1].firewall_name
    want        = var.custom_fw_names[1]
  }

  equal "custom_fw_name_ngfw3" {
    description = "Check NGFW 3 custom FW name."
    got         = module.mc_firenet_ha_azure.aviatrix_firewall_instance[2].firewall_name
    want        = var.custom_fw_names[2]
  }

  equal "custom_fw_name_ngfw4" {
    description = "Check NGFW 4 custom FW name."
    got         = module.mc_firenet_ha_azure.aviatrix_firewall_instance[3].firewall_name
    want        = var.custom_fw_names[3]
  }
}
