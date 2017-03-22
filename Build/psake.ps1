Properties {
       

    $Timestamp = Get-Date -UFormat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
 
    $lines = '----------------------------------------------------------------------'

    $cleanMessage = 'Executed Clean!'
	$testMessage = 'Executed Test!'
  
	$solutionDirectory = (Get-Item $SolutionFile).DirectoryName
	$outputDirectory= "$solutionDirectory\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"
	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"

	$workspaceMetaData = @{}

    $apitypes_yaml = Get-Content -Path $ML_WebServicesTypeConfig -Raw | ConvertFrom-Yaml 
                                                                           
    
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
	Write-Host "Getting experiment $experiment_name"
    $exp = Get-AmlExperiment -Location $ML_Location  -AuthorizationToken $ML_AuthorizationToken -WorkspaceId $ML_WorkspaceId | where Description -eq "$experiment_name"

    
    $node = Get-AmlExperimentNode -Location $ML_Location  -AuthorizationToken $ML_AuthorizationToken -WorkspaceId $ML_WorkspaceId  -ExperimentId $exp.ExperimentId -Comment "$trained_model_comment"


    Remove-Item "$ML_TrainedModelSrcDir\$ilearner_file_name" -Force -ErrorAction Ignore

    Download-AmlExperimentNodeOutput -Location $ML_Location  -AuthorizationToken $ML_AuthorizationToken -WorkspaceId $ML_WorkspaceId -ExperimentId $exp.ExperimentId -NodeId $node.Id -OutputPortName $trained_model_output_port -DownloadFileName "$ML_TrainedModelSrcDir\$ilearner_file_name"

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
task CreateOrUpdateWS -depends Init `
-description "Export Web Services Definition File (New Web Services)" `
{

	

	$webservice_definition_file_name = $apitypes_yaml.$webservice_type.websvc_definition_file_name 
	$websvc_name = $apitypes_yaml.$webservice_type.websvc_name 
	$websvc_title = $apitypes_yaml.$webservice_type.websvc_title

	
    $tmp_file = UpdateWSJson $websvc_name $websvc_title $webservice_definition_file_name 
    

    #Get-Content $tmp_file.FullName
    
    

    New-AzureRmMlWebService -Force -ResourceGroupName $ML_ResourceGroupName -Name $websvc_name -Location $ML_Location -DefinitionFile $tmp_file.FullName

}

task DeleteWS -depends Init `
-description "Export Web Services Definition File (New Web Services)" `
{

	$del_websvc_name = $apitypes_yaml.$webservice_type.websvc_name;
   

    Remove-AzureRmMlWebService -Force -ResourceGroupName $ML_ResourceGroupName  -Name $del_websvc_name 

}


########################################################################################################################
task UpdateWSILearner -depends Init 
-description "Generates a Blob URI from a local ilearner file and updates the Web Service"  {

   

    Select-AzureRmSubscription -SubscriptionName  $ML_SubscriptionName


    # Set a default storage account.
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $ML_ResourceGroupName -AccountName $ML_WSDeploy_Storage_Acct


    $guid = New-Guid
    $BlobName = $guid -replace '-',''

    $FilePath = "$ML_TrainedModelSrcDir\$local_ilearner_file_name"

    $blob = Set-AzureStorageBlobContent -Container  $ML_Storage_Acct_Assets_Container -File $FilePath -Blob "$BlobName.ilearner"

    $blob_uri = $blob.ICloudBlob.uri.AbsoluteUri

    Write-Host $blob_uri

}


function UpdateWSJson([string]$wsName, [string]$wsTitle, [string]$wsFile) {



	$wsd_json = Get-Content "$ML_WebServicesSrcDir\$wsFile" | ConvertFrom-Json

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
    
	
	
	$wsd_json.name = $wsName
	$wsd_json.properties.title = $wsTitle;
	
	#$wsd_json.name
	#$wsd_json.properties.title


    $tmp_file = New-TemporaryFile
    (ConvertTo-Json -Depth 20 $wsd_json)| set-content $tmp_file.FullName

	return $tmp_file
}