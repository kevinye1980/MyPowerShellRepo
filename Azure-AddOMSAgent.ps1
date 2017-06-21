
# Set subscription name
$subscriptionName = "<your subscription name>"

# Login to the specified subscription
Try{
  $subscription = Get-AzureRMSubscription -SubscriptionName $subscriptionName
}catch{
  Write-Error "Attempting to log into subscription $subscriptionName"
  Login-AzureRMAccount
  $subscription = Get-AzureRMSubscription -SubscriptionName $subscriptionName
}

# Set OMS workspace
$workspaceName = "<Your OMS workspace name>"
# Set the resource group which contains the target VMs
$VMresourcegroup = "<Your resource group name>"


Try{
    # Connect to OMS workspace
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

