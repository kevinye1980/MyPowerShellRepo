<# 
	.SYNOPSIS
	This sciprt is used to install OMS agent on Azure VMs in a particular resource group. 
  
	.DESCRIPTION
	This sciprt is used to install OMS agent on Azure VMs in a particular resource group. 
  Azure VMs must be in running state. 
  
  
	.PARAMETER subscriptionName
	Your Azure subscription name.
	.PARAMETER workspaceName
  Your OMS workspace name
  .PARAMETER VMresourcegroup
  The Azure resource group which contains VMs you want to enable OMS agent
  

	.INPUTS
	Nothing

	.OUTPUTS
	Nothing
	
	.NOTES
    Author: Kevin Ye

    
	
	DISCLAIMER:
	This sample script is not supported under any Microsoft standard support program or service. This sample
	script is provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties
	including, without limitation, any implied warranties of merchantability or of fitness for a particular
	purpose. The entire risk arising out of the use or performance of this sample script and documentation
	remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation,
	production, or delivery of this script be liable for any damages whatsoever (including, without limitation,
	damages for loss of business profits, business interruption, loss of business information, or other
	pecuniary loss) arising out of the use of or inability to use this sample script or documentation, even
	if Microsoft has been advised of the possibility of such damages.
	
#>

param(	
      [Parameter(Mandatory=$true)]
			[String]$subscriptionName,
      [Parameter(Mandatory=$true)]
			[String]$workspaceName,
      [Parameter(Mandatory=$true)]
			[String]$VMresourcegroup
			)
      
# Login to the specified subscription
Try{
  $subscription = Get-AzureRMSubscription -SubscriptionName $subscriptionName
}catch{
  Write-Error "Attempting to log into subscription $subscriptionName"
  Login-AzureRMAccount
  $subscription = Get-AzureRMSubscription -SubscriptionName $subscriptionName
}

# Connect to OMS workspace
Try{
    $workspace = (Get-AzureRmOperationalInsightsWorkspace).Where({$_.Name -eq $workspaceName})

    if ($workspace -eq $null)
    {
        Write-Error "Unable to find OMS Workspace $workspaceName. "
    }else
    {
      $workspaceId = $workspace.CustomerId
      $workspaceKey = (Get-AzureRmOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $workspace.ResourceGroupName -Name $workspace.Name).PrimarySharedKey

      $vms = Get-AzureRmVM -ResourceGroupName $VMresourcegroup
      foreach($vm in $vms)
      {
          # Retrieve VM power status: deallocated, stopped or running
          $vmStatus = Get-AzureRmVM -ResourceGroupName $VMresourcegroup -Name $vm.Name -Status
          $powerState = (get-culture).TextInfo.ToTitleCase(($vmStatus.statuses)[1].code.split("/")[1])

          # Only work on running VMs
          if($powerState -eq "running")
          {
            $location = $vm.Location
            $osType = $vm.StorageProfile.OsDisk.OsType
            
            # OMS Agent Extension name is different for Windows and Linux
            if ($osType -eq "Windows")
             { 
                $vmExtensionName = "MicrosoftMonitoringAgent"             
             }else{
                $vmExtensionName = "OmsAgentForLinux"
             }

             # Get VM extensions
             $vmExtension = Get-AzureRMVMExtension -ResourceGroupName $VMresourcegroup -VMName $vm.Name -Name $vmExtensionName
             if($vmExtension -eq $null)
             {
                  Set-AzureRmVMExtension -ResourceGroupName $VMresourcegroup -VMName $vm.Name -Name $vmExtensionName -Publisher 'Microsoft.EnterpriseCloud.Monitoring' -ExtensionType $vmExtensionName -TypeHandlerVersion '1.0' -Location $location -SettingString "{'workspaceId': '$workspaceId'}" -ProtectedSettingString "{'workspaceKey': '$workspaceKey'}"
             }else{
                  Write-Host "OMAgent Extension has been installed on $($vm.Name)"
             }

          }else{
             Write-Host "$($vm.Name) is not powered on. Skip it..."
          }
      }
   }
}catch{  
    Write-Error "Captured exception. Error:$($_.Exception.Message)"    
}

