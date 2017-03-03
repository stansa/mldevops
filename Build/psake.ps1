Properties {
       

    $Timestamp = Get-Date -UFormat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
 
    $lines = '----------------------------------------------------------------------'

    $cleanMessage = 'Executed Clean!'
	$testMessage = 'Executed Test!'
  
	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory= "$solutionDirectory\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"
	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"

                                                                               
    
}


task default -depends Init


########################################################################################################################
Task Init `
-description "Initialises the build by removing previous artifacts and creating output directories" `
{
    $lines
   
    #"Build System Details:"
    #Get-Item ENV:CR*
    #"`n"
    #Get-Variable | Out-String
    
    Select-AzureRmProfile -Path $ARM_SP_File
    
}


########################################################################################################################
task ExportTrainedModel -depends Init `
-description "Export Trained Model as iLearner File" `
{

    $exp = Get-AmlExperiment -Location $ML_Location  -AuthorizationToken $ML_AuthorizationToken -WorkspaceId $ML_WorkspaceId | where Description -eq "$experiment_name"

    
    $node = Get-AmlExperimentNode -Location $ML_Location  -AuthorizationToken $ML_AuthorizationToken -WorkspaceId $ML_WorkspaceId  -ExperimentId $exp.ExperimentId -Comment "$trained_model_comment"


    Remove-Item "$ML_TrainedModelSrcDir\$ilearner_file_name"

    Download-AmlExperimentNodeOutput -ExperimentId $exp.ExperimentId -NodeId $node.Id -OutputPortName $trained_model_output_port -DownloadFileName "$ML_TrainedModelSrcDir\$ilearner_file_name"

}




########################################################################################################################
task ExportWSDef -depends Init `
-description "Export Web Services Definition File (New Web Services)" `
{

    Select-AzureRmSubscription -SubscriptionName  $ML_SubscriptionName   
    $svc = Get-AzureRmMlWebService -Name $websvc_name -ResourceGroupName $ML_ResourceGroupName
    Export-AzureRmMlWebService -Force -WebService $svc -OutputFile "$ML_WebServicesSrcDir\$webservice_definition_file_name"

}








########################################################################################################################
task DeployWS -depends Init `
-description "Export Web Services Definition File (New Web Services)" `
{

    $wsd_json = Get-Content "$ML_WebServicesSrcDir\$webservice_definition_file_name" | ConvertFrom-Json

    $subsvalue_storage =@"
    {
    
      "name": "$ML_WSDeploy_Storage_Acct",
      "key": "$ML_WSDeploy_Storage_Acct_Key"
    }
"@

    $subsvalue_commplan =@"
    {
    
      "id": "$ML_WSDeploy_Commit_Plan_ID"
    }
"@

    $wsd_json.properties | add-member -Force -Name "storageAccount" -value (ConvertFrom-Json $subsvalue_storage) -MemberType NoteProperty
    $wsd_json.properties | add-member -Force -Name "CommitmentPlan" -value (ConvertFrom-Json $subsvalue_commplan) -MemberType NoteProperty
    $wsd_json.name = $websvc_name



    $tmp_file = New-TemporaryFile
    (ConvertTo-Json -Depth 20 $wsd_json)| set-content $tmp_file.FullName

    #Get-Content $tmp_file.FullName
    
    #For Staging, we remove any existing Web Services with same name name
    Remove-AzureRmMlWebService -Force -ResourceGroupName $ML_ResourceGroupName  -Name $websvc_name

    New-AzureRmMlWebService -Force -ResourceGroupName $ML_ResourceGroupName -Name $websvc_name -Location $ML_Location -DefinitionFile $tmp_file.FullName

}



########################################################################################################################
task CreateIlearnerBlob -depends Init {

   

    Select-AzureRmSubscription -SubscriptionName  $ML_SubscriptionName


    # Set a default storage account.
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $ML_ResourceGroupName -AccountName $ML_WSDeploy_Storage_Acct


    $guid = New-Guid
    $BlobName = $guid -replace '-',''

    $FilePath = "$ML_TrainedModelSrcDir\$ilearner_file_name"

    $blob = Set-AzureStorageBlobContent -Container  $ML_Storage_Acct_Assets_Container -File $FilePath -Blob "$BlobName.ilearner"

    $blob_uri = $blob.ICloudBlob.uri.AbsoluteUri

    Write-Host $blob_uri

}
