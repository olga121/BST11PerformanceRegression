--USE [BST_TestDataBank_Master]
--GO
/****** Object:  StoredProcedure [Generate].[Dynamic_PrebillRequest_From_Datagen]    Script Date: 4/3/2024 4:48:56 PM ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--ALTER PROCEDURE [Generate].[Dynamic_PrebillRequest_From_Datagen]
--(
	DECLARE @ClientDB					NVARCHAR(100),
	DECLARE @DocumentNbr_From			NVARCHAR(100),
	DECLARE @DocumentNbr_To				NVARCHAR(100) = NULL
--)

-- Execution pattern
--  EXEC [BST_TestDataBank_Master].[Generate].[Dynamic_PrebillRequest_From_Datagen] 'GCIProd_Perf', 'PB1000_GCI'
--AS 
--BEGIN

	DECLARE @USE NVARCHAR(100) = @ClientDB + '.sys.sp_executesql';
	

	EXEC @USE N'
	---------------------------------------------------------------------------
	-- C R E A T E   P R E B I L L   L I N E   I T E M   T A B L E   T Y P E --
	---------------------------------------------------------------------------
	IF (TYPE_ID(N''PrebillRequest_LineItem'') IS NULL)
	BEGIN
		--Create Prebill Request Line Item Table Type
		CREATE TYPE PrebillRequest_LineItem AS TABLE
		(
			--[Id]					UNIQUEIDENTIFIER,
			--[ParentId]			UNIQUEIDENTIFIER,
			[Project]				UNIQUEIDENTIFIER,
			[BillTerm]				UNIQUEIDENTIFIER,
			[Eligibility]			INT,
			[BillingReason]			INT,
			[ExcludeFromBilling]	BIT,
			[Results]				INT,
			[GenerateBackup]		BIT
		);
	END;
	
	WAITFOR DELAY ''00:00:02''';


	EXEC @USE N'

	BEGIN TRY

	---------------------------------
	-- D E C L A R E   T A B L E S --
	---------------------------------

	--Create Prebill Request Table Variable
	DECLARE @PrebillRequest TABLE
	(
		--[Id]						UNIQUEIDENTIFIER,
		[InputDocumentSuffix]		UNIQUEIDENTIFIER, 
		[DocumentNbr]				NVARCHAR(16), 
		[DocumentDate]				DATE,  
		[Description]				NVARCHAR(MAX), 
		[PostingDate]				UNIQUEIDENTIFIER, 
		[FromDate]					DATE, 
		[ThroughPostingDate]		UNIQUEIDENTIFIER, 
		[ThroughPostingDateDate]	DATE, 
		[ThroughTransactionDate]	DATE, 
		[DueDate]					DATE, 
		[HasAutoCounter]			BIT
	);
	
	--Declare the Prebill Request Line Item Table Variable
	DECLARE @PrebillRequest_LineItem AS PrebillRequest_LineItem;

	--Create Workflow Instance Table Variable
	DECLARE @WorkflowInstance TABLE
	(
		[Id]					UNIQUEIDENTIFIER, 
		[TypeId]				UNIQUEIDENTIFIER, 
		--[InstanceId]			UNIQUEIDENTIFIER, 
		[DisplayName]			SYSNAME, 
		[WorkflowId]			UNIQUEIDENTIFIER, 
		[LastActionId]			UNIQUEIDENTIFIER, 
		[StateId]				UNIQUEIDENTIFIER, 
		[LastUserId]			UNIQUEIDENTIFIER, 
		[OriginatingUserId]		UNIQUEIDENTIFIER, 
		[CheckedOutUserId]		UNIQUEIDENTIFIER, 
		[OriginatingEventDate]	DATETIME, 
		[LastEventDate]			DATETIME, 
		[Schemas]				INT, 
		[ProcessStatus]			INT, 
		[CurrentActionId]		UNIQUEIDENTIFIER 
	);

	--Create Prebill Request Metadata Table Variable
	DECLARE @PrebillRequestMetadata TABLE
	(
		--[Id]					UNIQUEIDENTIFIER,
		--[InstanceId]			UNIQUEIDENTIFIER,
		[CreatedBy]				SYSNAME,
		[CreatedDate]			DATETIME2(7),
		[LastUpdateBy]			SYSNAME,
		[CreatedByUserId]		UNIQUEIDENTIFIER,
		[LastUpdateByUserId]	UNIQUEIDENTIFIER,
		[LastUpdatedDate]		DATETIME2(7),
		[LastUpdatedFinalDate]	DATETIME2(7)
	); 

	--Create Event Table Variable
	DECLARE @Event TABLE 
	(
		[Id]					UNIQUEIDENTIFIER, 
		[TypeId]				UNIQUEIDENTIFIER, 
		--[InstanceId]			UNIQUEIDENTIFIER, 
		[DisplayName]			SYSNAME, 
		[WorkflowId]			UNIQUEIDENTIFIER, 
		[WorkflowName]			SYSNAME, 
		[WorkflowConditions]	NVARCHAR(MAX), 
		[ActionId]				UNIQUEIDENTIFIER,
		[ActionName]			SYSNAME, 
		[StateId]				UNIQUEIDENTIFIER, 
		[StateName]				SYSNAME, 
		[UserId]				UNIQUEIDENTIFIER, 
		[Schemas]				INT, 
		[ProcessStatus]			INT, 
		[EventDate]				DATETIME, 
		[Success]				BIT, 
		[Message]				NVARCHAR(MAX), 
		[Comment]				NVARCHAR(MAX)
	);


	-----------------------------------------------------------
	-- S E T   P R E - R E Q U I S I T E   V A R I A B L E S --
	-----------------------------------------------------------
	DECLARE @Domain						NVARCHAR(100)		= (SELECT DEFAULT_DOMAIN());
	DECLARE @NetworkExtension			NVARCHAR(100)		=	CASE
																	WHEN @Domain = ''BST''
																		THEN ''BSTGlobal.com''
																	WHEN @Domain = ''BSTTEST1''
																		THEN ''BSTTest1.net''
																	ELSE ''''
																END;
	DECLARE @StateName					NVARCHAR(100)		= ''PendingProcessing'';
	DECLARE @ActionName					NVARCHAR(100)		= ''Submit'';
	DECLARE @WorkflowName				NVARCHAR(100)		= ''InputNoApproval'';
	DECLARE @WorkflowConditions			NVARCHAR(100)		= NULL;
	DECLARE @PrebillRequestID			UNIQUEIDENTIFIER	= (SELECT NEWID());
	DECLARE @UserID						UNIQUEIDENTIFIER	= (SELECT Id FROM [dbo].[User] WITH (NOLOCK) WHERE Username = ''loadtester@'' + @NetworkExtension);
	DECLARE @TypeID						UNIQUEIDENTIFIER	= (SELECT Id FROM [dbo].[Type] WITH (NOLOCK) WHERE [Name] = ''PrebillRequest'');							
	DECLARE @WorkflowID					UNIQUEIDENTIFIER	= (SELECT Id FROM [dbo].[Type] WITH (NOLOCK) WHERE [Name] = @WorkflowName);					
	DECLARE @StateId					UNIQUEIDENTIFIER	= (SELECT Id FROM [dbo].[State] WITH (NOLOCK) WHERE [Name] = @StateName AND WorkflowID = @WorkflowID);
	DECLARE @OtherStateId				UNIQUEIDENTIFIER	= (SELECT ID FROM dbo.[State] WITH (NOLOCK) WHERE WorkflowId = @WorkflowID And [Name] = ''In'');
	DECLARE @ActionId					UNIQUEIDENTIFIER	= (SELECT Id FROM dbo.[Action] WITH (NOLOCK) Where [Name] = @ActionName AND StateId = @OtherStateId);
	DECLARE @Original_PrebillRequestId	UNIQUEIDENTIFIER	= (SELECT Id FROM [BST_TestDataBank_Master].[Datagen].[PrebillRequest] WITH (NOLOCK) WHERE DocumentNbr = @DocumentNbr_From AND ClientDatabase = @ClientDBName);

	--Set Document Number if Input is NULL
	IF (@DocumentNbr_To IS NULL)
	BEGIN
		SET @DocumentNbr_To = @DocumentNbr_From;
	END
	
	--Make sure that ''DGEN'' is prefixed to Document Number
	IF (SUBSTRING(@DocumentNbr_To,1,4) != ''DGEN'')
	BEGIN
		SET @DocumentNbr_To = ''DGEN'' + substring(@DocumentNbr_To, 1,7); --change!
	END
	

	-----------------------------------------------------
	-- P O P U L A T E   T A B L E   V A R I A B L E S --
	-----------------------------------------------------
	--Populate the Prebill Request
	INSERT INTO @PrebillRequest
	SELECT TOP 1 [InputDocumentSuffix], 
				 @DocumentNbr_To [DocumentNbr], 
				 GETDATE() [DocumentDate],  
				 [Description], 
				 [PostingDate], 
				 [FromDate], 
				 [ThroughPostingDate], 
				 [ThroughPostingDateDate], 
				 [ThroughTransactionDate], 
				 [DueDate], 
				 [HasAutoCounter]
	FROM [BST_TestDataBank_Master].[Datagen].[PrebillRequest] WITH (NOLOCK)
	WHERE Id = @Original_PrebillRequestId;

	--Populate the Line Items
	INSERT INTO @PrebillRequest_LineItem
	SELECT [Project],
		   [BillTerm],
		   [Eligibility],
		   [BillingReason],
		   [ExcludeFromBilling],
		   [Results],
		   [GenerateBackup]
	FROM [BST_TestDataBank_Master].[Datagen].PrebillRequest_LineItem WITH (NOLOCK)
	WHERE ParentId = @Original_PrebillRequestId	

	--Populate the Workflow Item
	INSERT INTO @WorkflowInstance
	SELECT NEWID() [ID], 
		   @TypeID [TypeID], 
		   @DocumentNbr_To [DisplayName], 
		   @WorkflowID [WorkFlowid], 
		   @ActionId [LastActionid], 
		   @StateId [Stateid],
		   @UserID [LastUserId], 
		   @UserID [OriginatingUserId], 
		   NULL [CheckedoutUserid], 
		   GETDATE() [OriginatingEventDate], 
		   GETDATE() [LastEventDate], 
		   2 [Schemas], 
		   0 [ProcessStatus],
		   NULL [CurrentActionId]  

	--Populate the Metadata
	INSERT INTO @PrebillRequestMetadata
	SELECT ''loadtester'' [CreatedBy], 
		   GETDATE() [CreatedDate], 
		   ''loadtester'' [LastUpdateBy], 
		   @UserID [CreatedByUserId], 
		   @UserID [LastUpdateByUserId], 
		   GETDATE() [LastUpdatedDate], 
		   NULL [LastUpdatedFinalDate]
		   
	--Populate the Event
	INSERT INTO @Event
	SELECT NEWID() [ID],
		   @TypeId [TypeID], 
		   @DocumentNbr_To [DisplayName], 
		   @WorkflowId [WorkflowID], 
		   @WorkflowName [WorkflowName], 
		   @WorkflowConditions [WorkflowConditions], 
		   @ActionId [ActionID], 
		   @ActionName  [ActionName], 
		   @StateId [StateID], 
		   @StateName [StateName],
		   @UserID [UserID],
		   2 [Schemas],
		   1 [ProcessStatus], 
		   GETDATE() [EventDate], 
		   1 [Success], 
		   ''Success'' [Message], 
		   ''Prebill Request From Datagen'' [Comment]

	--Start the transaction and insert into client database tables
	BEGIN TRAN NewPrebillRequest

		DECLARE @GeneratedIDTable TABLE ([Id] UNIQUEIDENTIFIER);
		DECLARE @GeneratedID UNIQUEIDENTIFIER;
		DECLARE @GenerateBackupCount INT;

		--Insert into draft prebill request, and store the generated id
		INSERT INTO [Draft].[PrebillRequest] 
		(
			[InputDocumentSuffix], 
			[DocumentNbr], 
			[DocumentDate], 
			[Description], 
			[PostingDate], 
			[FromDate], 
			[ThroughPostingDate], 
			[ThroughPostingDateDate], 
			[ThroughTransactionDate], 
			[DueDate], 
		    [HasAutoCounter]
		)
		OUTPUT inserted.ID INTO @GeneratedIDTable
		SELECT [InputDocumentSuffix], 
			   [DocumentNbr], 
		 	   [DocumentDate], 
			   [Description], 
			   [PostingDate], 
			   [FromDate], 
			   [ThroughPostingDate], 
			   [ThroughPostingDateDate], 
			   [ThroughTransactionDate], 
		 	   [DueDate], 
		       [HasAutoCounter]
		FROM @PrebillRequest;

		--Set the generated prebill request id from the GeneratedIDTable
		SET @GeneratedID = (SELECT ID FROM @GeneratedIDTable);
		--Check if any of the line items are selected to generate backup
		SET @GenerateBackupCount = (SELECT COUNT(*) FROM @PrebillRequest_LineItem WHERE GenerateBackup = 1);

		--Insert Prebill Request Line Items
		IF (@GenerateBackupCount = 0)
		BEGIN
			INSERT INTO [Draft].[PrebillRequest_LineItem] 
			(
				[ParentId],
				[Project],
				[BillTerm],
				[Eligibility],
				[BillingReason],
				[ExcludeFromBilling],
				[Results]
			)
			SELECT @GeneratedID,
				   [Project],
				   [BillTerm],
				   [Eligibility],
				   [BillingReason],
				   [ExcludeFromBilling],
				   [Results]
			FROM @PrebillRequest_LineItem
		END
		ELSE
		BEGIN
			
			IF (COL_LENGTH(''[Draft].[PrebillRequest_LineItem]'', ''GenerateBackup'') IS NULL)
			BEGIN
				DECLARE @genBackupErrorMsg NVARCHAR(MAX) = ''GenerateBackup option set to TRUE for '' + CONVERT(NVARCHAR(100), @GenerateBackupCount) + '' prebills, but the GenerateBackup column does not exist in [Draft].[PrebillRequest_LineItem]''; 
				RAISERROR 
				(
					@genBackupErrorMsg, 
			 	    18, -- Severity,  
					1
				);
				RETURN;
			END

			EXEC @USE N''
			INSERT INTO [Draft].[PrebillRequest_LineItem] 
			(
				[ParentId],
				[Project],
				[BillTerm],
				[Eligibility],
				[BillingReason],
				[ExcludeFromBilling],
				[Results],
				[GenerateBackup]
			)
			SELECT @GeneratedID,
				   [Project],
				   [BillTerm],
				   [Eligibility],
				   [BillingReason],
				   [ExcludeFromBilling],
				   [Results],
				   [GenerateBackup]
			FROM @PrebillRequest_LineItem''
			,N''@PrebillRequest_LineItem PrebillRequest_LineItem READONLY, @GeneratedID UNIQUEIDENTIFIER''
			,@PrebillRequest_LineItem = @PrebillRequest_LineItem, @GeneratedID = @GeneratedID
		END

		--Insert into Workflow Instance Table
		INSERT INTO [dbo].[WorkflowInstance] 
		(
			[Id], 
			[TypeId], 
			[InstanceId], 
			[DisplayName], 
			[WorkflowId], 
			[LastActionId], 
			[StateId], 
			[LastUserId], 
			[OriginatingUserId], 
			[CheckedOutUserId], 
			[OriginatingEventDate], 
			[LastEventDate], 
			[Schemas], 
			[ProcessStatus], 
			[CurrentActionId]
		)
		SELECT [ID], 
			   [TypeID], 
			   @GeneratedID [InstanceID], 
		       [DisplayName], 
		       [WorkFlowid], 
		       [LastActionid], 
		       [Stateid],
		       [LastUserId], 
		       [OriginatingUserId], 
		       [CheckedoutUserid], 
		       [OriginatingEventDate], 
		       [LastEventDate], 
		       [Schemas], 
		       [ProcessStatus],
		       [CurrentActionId] 
		FROM @WorkflowInstance 

		--Insert into the Prebill Request Metadata Table
		INSERT INTO [Metadata].[PrebillRequest]
		(
			[InstanceId],
			[CreatedBy],
			[CreatedDate],
			[LastUpdateBy],
			[CreatedByUserId],
			[LastUpdateByUserId],
			[LastUpdatedDate],
			[LastUpdatedFinalDate]
		)
		SELECT @GeneratedID,
			   [CreatedBy], 
			   [CreatedDate], 
		       [LastUpdateBy], 
		       [CreatedByUserId], 
		       [LastUpdateByUserId], 
		       [LastUpdatedDate], 
		       [LastUpdatedFinalDate]
		FROM @PrebillRequestMetadata

		--Insert into Event Table
		INSERT INTO [dbo].[Event]
		(
			[Id], 
			[TypeId], 
			[InstanceId], 
			[DisplayName], 
			[WorkflowId], 
			[WorkflowName], 
			[WorkflowConditions], 
			[ActionId],
			[ActionName], 
			[StateId], 
			[StateName], 
			[UserId], 
			[Schemas], 
			[ProcessStatus], 
			[EventDate], 
			[Success], 
			[Message], 
			[Comment]
		)
		SELECT [Id], 
			   [TypeId], 
			   @GeneratedID, 
			   [DisplayName], 
			   [WorkflowId], 
			   [WorkflowName], 
			   [WorkflowConditions], 
			   [ActionId],
			   [ActionName], 
			   [StateId], 
			   [StateName], 
			   [UserId], 
			   [Schemas], 
			   [ProcessStatus], 
			   [EventDate], 
			   [Success], 
			   [Message], 
			   [Comment]
		FROM @Event

	COMMIT TRAN  NewPrebillRequest

	END TRY
	BEGIN CATCH

		-----------------------------------
		-- E R R O R   R E P O R T I N G --
		-----------------------------------

		DECLARE @ErrorMessage	NVARCHAR(4000);
		DECLARE @ErrorSeverity	INT;
		DECLARE @ErrorState		INT;

		SELECT @ErrorMessage = ERROR_MESSAGE(),
			   @ErrorSeverity = ERROR_SEVERITY(),
			   @ErrorState = ERROR_STATE();

		IF @@TRANCOUNT > 0
		   ROLLBACK TRANSACTION NewPrebillRequest
		   RAISERROR 
		   (
				@ErrorMessage, -- Message text.
				@ErrorSeverity, -- Severity.
				@ErrorState -- State.
		   );

	END CATCH

	',
	N'@ClientDBName NVARCHAR(100), @DocumentNbr_From NVARCHAR(100), @DocumentNbr_To NVARCHAR(100), @USE NVARCHAR(100)',
	@ClientDBName = @ClientDB, @DocumentNbr_From = @DocumentNbr_From, @DocumentNbr_To = @DocumentNbr_To, @USE = @USE

--END;--