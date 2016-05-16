wassaim
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.RaisinGetReleaseItems 
	@Tag VARCHAR(MAX)
AS
BEGIN
	DECLARE @TagId uniqueidentifier,@PropertyId INT, @Tags VARCHAR(MAX), @ItemID INT 

	SELECT @TagId=TagId FROM TFS_AKACOllection..tbl_TagDefinition t
	WHERE t.[name] = @Tag

	SELECT @PropertyId=PropertyId FROM TFS_AKACOllection..[tbl_PropertyDefinition] WHERE [NAME] = 'Microsoft.TeamFoundation.Tagging.TagDefinition.' + cast(@TagId as varchar(MAX))

	--select @TagId TagId,@PropertyId PropertyId

	select w.ID,w.[Work Item Type],w.Title,w.State,cwi.System_AssignedTo AssignedTo,cwi.IterationPath [Iteration],AreaPath [Area],
	'http://tfs2013-vm:8080/tfs/AKACollection/Raisin/Team B/_workitems#id=' + CAST(w.ID as varchar(MAX)) + '&_a=edit' URL, CAST('NULL' AS VARCHAR(MAX)) Tags,
	w.Fld10084 [Backlog Priority], w.fld10102 DeploymentDate
	INTO #ReleaseItems
	--,w.fld10101 Branch,w.Fld10084 BacklogPriority, 
	--w.fld10102 DeploymentDate,w.[Changed Date]--,tmp.*,w.* 
	from 
	( 
		SELECT CAST(PV.ArtifactID as int) ItemID, PV.IntValue FROM TFS_AKACOllection..tbl_propertyValue PV
		INNER JOIN
		(
			SELECT PropertyId,ArtifactID,MAX([VERSION]) Ver 
			FROM TFS_AKACOllection..tbl_propertyValue  
			where PropertyId = @PropertyId 
			group by PropertyId,ArtifactID
		) PV2 ON PV.PropertyId = PV2.PropertyId AND PV.ArtifactID = PV2.ArtifactID AND Pv.[Version] = PV2.Ver AND PV.IntValue = 0
		where pv.PropertyId = @PropertyId 
	) tmp
	INNER JOIN TFS_AKACOllection..WorkItemsLatest w ON w.ID = ItemID
	LEFT OUTER JOIN tfs_warehouse..CurrentWorkItemView cwi ON cwi.system_id = w.ID 

	WHILE EXISTS(SELECT * FROM #ReleaseItems WHERE Tags = 'NULL')
	BEGIN
		SELECT @Tags = '', @ItemID = NULL
		
		SELECT TOP 1 @ItemID = ID FROM #ReleaseItems WHERE Tags = 'NULL'
		
		SELECT @Tags = ISNULL(@Tags,'') + ISNULL(t.[name],'') + ', ' 
		FROM TFS_AKACOllection..tbl_propertyValue PV
		INNER JOIN
		(
			SELECT ArtifactID,PropertyId,MAX([VERSION]) Ver 
			FROM TFS_AKACOllection..tbl_propertyValue  
			where ArtifactID = @ItemID 
			group by ArtifactID,PropertyId
		) PV2 ON PV.PropertyId = PV2.PropertyId AND PV.ArtifactID = PV2.ArtifactID AND Pv.[Version] = PV2.Ver AND PV.IntValue = 0
		INNER JOIN TFS_AKACOllection..[tbl_PropertyDefinition] pd ON pd.PropertyId = PV.PropertyId
		INNER JOIN TFS_AKACOllection..tbl_TagDefinition t ON CAST(t.TagId AS VARCHAR(MAX))=REPLACE(pd.[Name],'Microsoft.TeamFoundation.Tagging.TagDefinition.','')
		where pv.ArtifactID = @ItemID 
		
		UPDATE #ReleaseItems
		SET Tags = CASE WHEN LEN(ISNULL(@Tags,'')) > 0 THEN LEFT(@Tags,LEN(@Tags)-1) ELSE '' END
		WHERE ID = @ItemId
	END	
			
	SELECT * FROM #ReleaseItems	ORDER BY [Backlog Priority]

	DROP TABLE #ReleaseItems

END
GO
