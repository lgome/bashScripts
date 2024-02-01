#!/bin/bash

    for i in /u01/SosTreatFileUploadCN/logs /u01/SosAutoSegmentation/logs /u01/SosPre_IPL_TFU/logs /u01/SosTPS_IPLEvent/logs /u01/SosCQA/logs /u01/SosAssetReplicationCN/logs

     do
       find {$i} -name '*.log.*' -mtime +15 -ls
     done
