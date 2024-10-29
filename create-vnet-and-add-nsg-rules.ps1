# user input
$resourceGroupName = Read-Host -Prompt "Enter the name of the resource group"
$location = Read-Host -Prompt "Enter the location (e.g., eastus)"
$nsgName = Read-Host -Prompt "Enter the name of the Network Security Group"
$vnetName = Read-Host -Prompt "Enter the name of the Virtual Network"
$subnetName = Read-Host -Prompt "Enter the name of the Subnet"

# check if the VNet exists
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName -ErrorAction SilentlyContinue

if (-not $vnet) {
    # VNet does not exist, so create a new one
    Write-Host "Virtual Network does not exist. Creating a new VNet..."

    $vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name $vnetName -AddressPrefix "10.0.0.0/16"
    $subnet = Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.1.0/24" -VirtualNetwork $vnet
    $vnet | Set-AzVirtualNetwork
} else {
    Write-Host "Virtual Network already exists."
    $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }

    if (-not $subnet) {
        Write-Host "Subnet does not exist. Creating a new subnet..."
        $subnet = Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.1.0/24" -VirtualNetwork $vnet
        $vnet | Set-AzVirtualNetwork
    } else {
        Write-Host "Subnet already exists."
    }
}

# create new Network Security Group
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $nsgName

# define inbound security rule
$rule1 = New-AzNetworkSecurityRuleConfig -Name "Allow-SSH" `
    -Description "Allow SSH traffic" `
    -Access "Allow" `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 100 `
    -SourceAddressPrefix "Internet" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange "22"

# define outbound security rule
$rule2 = New-AzNetworkSecurityRuleConfig -Name "Allow-HTTP-Out" `
    -Description "Allow outbound HTTP traffic" `
    -Access "Allow" `
    -Protocol "Tcp" `
    -Direction "Outbound" `
    -Priority 200 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange "80"

# add the rules to nsg
$nsg.SecurityRules.Add($rule1)
$nsg.SecurityRules.Add($rule2)

# update the Network Security Group
Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg

# associate nsg with the subnet
$subnetConfig = Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnetName -AddressPrefix $subnet.AddressPrefix -NetworkSecurityGroup $nsg

# apply updated configuration to the virtual network
$vnet | Set-AzVirtualNetwork

Write-Host "Network Security Group and rules deployed successfully!"
