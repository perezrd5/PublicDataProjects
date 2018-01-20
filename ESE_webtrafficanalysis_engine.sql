USE [NetInsightOUP]
GO


 --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 --!!!!! CREATE TABLES COMMENTED TO PREVENT DELETION OF DATA WHEN RERUNNING SCRIPT !!!!!
 --!!!!!         BE SURE TO UNCOMMENT WHEN RUNNING SCRIPT ON NEW DATABASE		   !!!!!
 --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

/****** Object:  Table [dbo].[ESELogProcess]    Script Date: 02/20/2009 13:44:13 ******/
--IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[ESELogProcess]') 
--		and OBJECTPROPERTY(id, N'IsUserTable') = 1)
--	DROP TABLE [dbo].[ESELogProcess]
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
--SET ANSI_PADDING ON
--GO
--CREATE TABLE [dbo].[ESELogProcess](
--	[LogProcessID] [int] IDENTITY(1,1) NOT NULL,
--	[LogDateTime] [datetime] NOT NULL,
--	[LogProfile] [varchar](128) COLLATE Latin1_General_CS_AS NOT NULL,
--	[LogProcess] [varchar](255) COLLATE Latin1_General_CS_AS NOT NULL,
--	[LogStartDate] [datetime] NULL,
--	[LogEndDate] [datetime] NULL,
--	[LogStartViewID] [int] NULL,
--	[LogEndViewID] [int] NULL,
--	[LogRecords] [int] NULL,
--	[LogErrNum] [varchar](128) COLLATE Latin1_General_CS_AS NULL,
--	[LogErrCode] [varchar](128) COLLATE Latin1_General_CS_AS NULL,
--	[LogErrDesc] [varchar](128) COLLATE Latin1_General_CS_AS NULL,
-- CONSTRAINT [PK_ESELogProcess] PRIMARY KEY CLUSTERED 
--(
--	[LogProcessID] ASC
--)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
--) ON [PRIMARY]
--GO
--SET ANSI_PADDING OFF


/****** Object:  Table [dbo].[ESELogEvents]    Script Date: 02/20/2009 13:44:13 ******/
--IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[ESELogEvents]') 
--		and OBJECTPROPERTY(id, N'IsUserTable') = 1)
--	DROP TABLE [dbo].[ESELogEvents]
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
--SET ANSI_PADDING ON
--GO
--CREATE TABLE [dbo].[ESELogEvents](
--	[LogEventID] [int] IDENTITY(1,1) NOT NULL,
--	[LogDateTime] [datetime] NOT NULL,
--	[LogProfile] [varchar](128) COLLATE Latin1_General_CS_AS NOT NULL,
--	[LogTask] [varchar](128) COLLATE Latin1_General_CS_AS NOT NULL,
--	[LogEvent] [varchar](255) COLLATE Latin1_General_CS_AS NOT NULL,
--	[LogRecords] [int] NULL,
--	[LogErrNum] [varchar](128) COLLATE Latin1_General_CS_AS NULL,
--	[LogErrCode] [varchar](128) COLLATE Latin1_General_CS_AS NULL,
--	[LogErrDesc] [varchar](128) COLLATE Latin1_General_CS_AS NULL,
-- CONSTRAINT [PK_ESELogEvents] PRIMARY KEY CLUSTERED 
--(
--	[LogEventID] ASC
--)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
--) ON [PRIMARY]
--GO
--SET ANSI_PADDING OFF


/****** Object:  UserDefinedFunction [dbo].[ESE_Get_PageBreakdown]    Script Date: 02/23/2009 04:15:28 ******/
IF OBJECT_ID(N'dbo.[ESE_Get_PageBreakdown]') IS NOT NULL
    DROP FUNCTION dbo.[ESE_Get_PageBreakdown];
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- FUNCTION:	[ESE_Get_PageBreakdown]
-- CREATED:		02/23/09
-- BY:			Doug Perez
-- DESC:		Parses PageBreakdown from Page Column
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION [dbo].[ESE_Get_PageBreakdown] (@PageURL varchar (750))
RETURNS varchar (750) 
AS
BEGIN
	
	DECLARE @PageBreakdown VARCHAR(750)

	IF PATINDEX('%?%',@PageURL) > 0
		SELECT @PageBreakdown = SUBSTRING(@PageURL, PATINDEX('%?%',@PageURL), LEN(@PageURL) - PATINDEX('%?%', @PageURL) + 1)

	RETURN @PageBreakdown

END
GO


/****** Object:  UserDefinedFunction [dbo].[ESE_Get_Page]    Script Date: 02/23/2009 04:15:28 ******/
IF OBJECT_ID(N'dbo.[ESE_Get_Page]') IS NOT NULL
    DROP FUNCTION dbo.[ESE_Get_Page];
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- FUNCTION:	[ESE_Get_Page]
-- CREATED:		02/23/09
-- BY:			Doug Perez
-- DESC:		Parses PageBreakdown from Page Column
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION [dbo].[ESE_Get_Page] (@PageURL varchar (750))
RETURNS varchar (750) 
AS
BEGIN

	IF PATINDEX('%?%',@PageURL) > 0
		SELECT @PageURL = SUBSTRING(@PageURL, 0, PATINDEX('%?%',@PageURL))

	RETURN @PageURL

END
GO



/****** Object:  UserDefinedFunction [dbo].[ESE_Get_HostIP]    Script Date: 02/23/2009 04:15:28 ******/
IF OBJECT_ID(N'dbo.[ESE_Get_HostIP]') IS NOT NULL
    DROP FUNCTION dbo.[ESE_Get_HostIP];
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- FUNCTION:	[ESE_Get_HostIP]
-- CREATED:		02/23/09
-- BY:			Doug Perez
-- DESC:		Parses HostIP from HostNum
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE FUNCTION [dbo].[ESE_Get_HostIP] ( @IPNum bigint)
RETURNS varchar(15) -- dotted format IP address for host number
AS
BEGIN
DECLARE @IPAddr varchar(15)

SELECT @IPAddr= convert( varchar(3), convert( int, convert(binary(1), (@IPNum & 0xFF000000) / 0x1000000 ))) + '.' +
           convert( varchar(3), convert( int, convert(binary(1), (@IPNum & 0xFF0000) / 0x10000 ))) + '.'+
           convert( varchar(3), convert( int, convert(binary(1), (@IPNum & 0xFF00) / 0x100 ))) + '.' +
           convert( varchar(3), convert( int, convert(binary(1), @IPNum)))           
    RETURN @IPAddr
END
GO




/****** Object:  UserDefinedFunction [dbo].[ESE_Get_HostNum]    Script Date: 02/23/2009 04:15:28 ******/
IF OBJECT_ID(N'dbo.[ESE_Get_HostNum]') IS NOT NULL
    DROP FUNCTION dbo.[ESE_Get_HostNum];
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- FUNCTION:	[ESE_Get_HostNum]
-- CREATED:		02/23/09
-- BY:			Doug Perez
-- DESC:		Gets HostNum from HostIP
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION [dbo].[ESE_Get_HostNum] ( @Host varchar (120))
RETURNS bigint -- Ordinal number for host octets
AS
BEGIN
    DECLARE @Loop int, @Value bigint, @Offset int, @Next int
    DECLARE @Base bigint
    SET @Value = 0
    SET @Base = 256
    SET @Offset = 1
    SET @Loop = 3

    IF CHARINDEX ( '.', @Host, @Offset ) > 0
    BEGIN
	    WHILE (@Loop >= 0)
	    BEGIN
	    	SET @Next = CHARINDEX ( '.', @Host, @Offset )
		IF (@Next = 0) --End of string
	    		SET @Next = LEN (@Host) + 1
	     
		IF @Next-@Offset > 0 
			IF ISNUMERIC ( SUBSTRING ( @Host, @Offset, @Next-@Offset )) = 1
				SET @Value = @Value + ( SUBSTRING ( @Host, @Offset, @Next-@Offset ) * POWER (@Base, @Loop) )
	
	        SET @Offset = @Next + 1
	        SET @Loop = @Loop - 1
	    END
    END
    RETURN @Value
END
GO




/****** Object:  StoredProcedure [dbo].[ESE_Insert_LogProcess]  Script Date: 02/21/2009 21:43:12 GMT ******/
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ESE_Insert_LogProcess]') AND type in (N'P', N'PC'))
BEGIN
	DROP PROCEDURE [ESE_Insert_LogProcess]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROCEDURE:	[ESE_Insert_LogProcess]
-- CREATED:		02/20/09
-- BY:			Doug Perez
-- DESC:		Inserts record into ESELogProcess table
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[ESE_Insert_LogProcess]  
(	@LogProfile varchar(128), 
	@LogProcess varchar(255), 
	@LogStartDate datetime,
	@LogEndDate datetime,
	@LogStartViewID int, 
	@LogEndViewID int, 
	@LogRecords int, 
	@LogErrNum varchar(128) = NULL, 
	@LogErrCode varchar(128) = NULL, 
	@LogErrDesc varchar(128) = NULL)
AS

	INSERT INTO ESELogProcess (LogDateTime, LogProfile, LogProcess, LogStartDate,
		LogEndDate, LogStartViewID, LogEndViewID, LogRecords, 
		LogErrNum, LogErrCode, LogErrDesc)
	VALUES (GETDATE(), @LogProfile, @LogProcess, @LogStartDate, @LogEndDate,
		@LogStartViewID, @LogEndViewID, @LogRecords, @LogErrNum, @LogErrCode, @LogErrDesc)

GO
SET ANSI_PADDING OFF


/****** Object:  StoredProcedure [dbo].[ESE_Insert_LogEvent]  Script Date: 02/21/2009 21:43:12 GMT ******/
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ESE_Insert_LogEvent]') AND type in (N'P', N'PC'))
BEGIN
	DROP PROCEDURE [ESE_Insert_LogEvent]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROCEDURE:	[ESE_Insert_LogEvent]
-- CREATED:		02/20/09
-- BY:			Doug Perez
-- DESC:		Inserts record into ESELogEvent table
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[ESE_Insert_LogEvent]  
(	@LogProfile varchar(128), 
	@LogTask varchar(128), 
	@LogEvent varchar(255), 
	@LogRecords int, 
	@LogErrNum varchar(128) = NULL, 
	@LogErrCode varchar(128) = NULL, 
	@LogErrDesc varchar(128) = NULL)
AS

	INSERT INTO ESELogEvents (LogDateTime, LogProfile, LogTask, LogEvent, LogRecords, 
		LogErrNum, LogErrCode, LogErrDesc)
	VALUES (GETDATE(), @LogProfile, @LogTask, @LogEvent, @LogRecords, @LogErrNum, 
		@LogErrCode, @LogErrDesc)

GO
SET ANSI_PADDING OFF



/****** Object:  StoredProcedure [dbo].[ESE_Create_ESEData]   Script Date: 02/21/2009 17:21:30 GMT ******/
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ESE_Create_ESEData]') AND type in (N'P', N'PC'))
BEGIN
	DROP PROCEDURE [ESE_Create_ESEData]
END
/****** Object:  StoredProcedure [dbo].[ESE_Create_ESEData]    Script Date: 09/23/2010 20:11:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROCEDURE:	[ESE_Create_ESEData]
-- CREATED:		02/22/09
-- BY:			Doug Perez
-- DESC:		Creates temp table for profile used by ESE_DataAnalyzer to store 
--				data being processed
-- NOTES:		EXEC ESE_Create_ESEData 'oup'
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[ESE_Create_ESEData]
(	@Profile			VARCHAR(128),
	@ArchiveTable		BIT = NULL,
	@MonthlyTable		BIT = NULL)
AS
BEGIN
	
	DECLARE @SQL AS VARCHAR(8000)
	DECLARE @TableType AS VARCHAR(50)

	IF @ArchiveTable = 1 
		SET @TableType = 'Arc'
	ELSE IF @MonthlyTable = 1
		SET @TableType = 'Monthly'
	ELSE 
		SET @TableType = ''


	SELECT @SQL = '
		if exists (select * from dbo.sysobjects where id = object_id(N''[dbo].[' + @Profile + 'Data' + @TableType + ']'') 
				and OBJECTPROPERTY(id, N''IsUserTable'') = 1)
			drop table [dbo].[' + @Profile + 'Data' + @TableType + ']


		CREATE TABLE [dbo].[' + @Profile + 'Data' + @TableType + '] (
			[ViewDateTime] [datetime] NULL,
			[PageID] [int] NOT NULL,
			[HostID] [int] NOT NULL,
			[VisitID] [int] NOT NULL,
			[ViewID] [int] NOT NULL,
			[UserID] [int] NULL,
			[SiteID] [varchar](128) NULL,
			[SiteID2] [varchar](128) NULL,
			[SiteID3] [varchar](128) NULL,
			[ProductID] [varchar](128) NULL,
			[JournalID] [varchar](128) NULL,
			[ArticleID] [varchar](128) NULL,
			[ProductCode] [varchar](50) NULL,
			[Product] [varchar](155) NULL,
			[ProdType] [varchar](128) NULL,
			[ProdSType] [varchar](128) NULL,
			[SubjectArea] [varchar](128) NULL,
			[CODEN] [varchar](50) NULL,
			[Publisher] [varchar](128) NULL,
			[OrigPublisher] [varchar](128) NULL,
			[CVIPS] [varchar](50) NULL,
			[Article] [varchar](275) NULL,
			[Vol] [varchar](50) NULL,
			[Iss] [varchar](50) NULL,
			[Pg] [varchar](50) NULL,
			[PbYear] [char](10) NULL,
			[PbMonthDay] [char](10) NULL,
			[Authors] [varchar](255) NULL,
			[Journal] [varchar](200) NULL,
			[IssueType] [varchar](50) NULL,
			[PageCode] [char](1) NULL,
			[EventType] [varchar](120) NULL,
			[PageType] [varchar](120) NULL,
			[FullTextType] [varchar](120) NULL,
			[ReqYear] [int] NULL,
			[ReqMonth] [int] NULL,
			[Page] [varchar](750) NULL,
			[PageBreakdown] [varchar](750) NULL,
			[Redirect] [int] NULL,
			[Domain] [varchar](128) NULL,
			[Platform] [varchar](128) NULL,
			[HostIP] [varchar](50) NULL,
			[HostNum] [bigint] NULL,
			[AssignedTo] [varchar](128) NULL,
			[Account] [varchar](200) NULL,
			[AcctType] [varchar](128) NULL,
			[AuthAcct] [varchar](200) NULL,
			[Group] [varchar](128) NULL,
			[Consortium] [varchar](200) NULL,
			[Member] [varchar](128) NULL,
			[Denied] [varchar](50) NULL,
			[Subscribe] [varchar](50) NULL,
			[ReferrerDomain] [varchar](128) NULL,
			[Archive] [varchar](50) NULL,
			[COUNTER] [varchar](50) NULL,
			[Supplier] [varchar](50) NULL,
			[ISBN] [varchar] (50) NULL,
			[DOI] [varchar] (50) NULL,
			[PrintDate] [varchar] (50) NULL,
			[FPorArtID] [varchar] (50) NULL,
			[OnlineDate] [varchar] (50) NULL,
			[ContType] [varchar] (128) NULL,
			[OITaxonomy] [varchar] (255) NULL,
			[AdvAccDate] [varchar] (50) NULL,
			[IssorSupp] [varchar] (50) NULL,
			[IssCovDate] [varchar] (50) NULL,
			[ConVolume] [varchar] (128) NULL,
			[ConLastPg] [varchar] (50) NULL,
			[ProdTax] [varchar] (255) NULL,
			[site] [varchar] (255) NULL,
			[SubStatus] [varchar] (50) NULL,
			[SubType] [varchar] (50) NULL,
			[sams_consortia] [varchar] (300) NULL		
		) ON [PRIMARY]'
	EXEC (@SQL)

	SELECT @SQL = '
		CREATE NONCLUSTERED INDEX [IX_' + @Profile + 'Data' + @TableType + '_ViewID]
		ON [dbo].[' + @Profile + 'Data' + @TableType + '] ([ViewID])'
	EXEC (@SQL)

END
GO


/****** Object:  StoredProcedure [dbo].[ESE_DataAnalyzer]  Script Date: 02/21/2009 21:43:12 GMT ******/
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[getMonthShortName]') AND type in (N'FN', N'TF'))
BEGIN
	DROP FUNCTION [dbo].[getMonthShortName]
END

/****** Object:  UserDefinedFunction [dbo].[getMonthShortName]    Script Date: 1/17/2014 2:37:52 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Doug Perez
-- Create date: 1/16/2014
-- Description:	Returns short month name from integer input
-- =============================================
CREATE FUNCTION [dbo].[getMonthShortName]
(
	@month INT
)
RETURNS VARCHAR(3)
AS
BEGIN

	DECLARE @monthName VARCHAR(3)

	SELECT @monthName = CASE @month
							WHEN 1 THEN 'JAN'
							WHEN 2 THEN 'FEB'
							WHEN 3 THEN 'MAR'
							WHEN 4 THEN 'APR'
							WHEN 5 THEN 'MAY'
							WHEN 6 THEN 'JUN'
							WHEN 7 THEN 'JUL'
							WHEN 8 THEN 'AUG'
							WHEN 9 THEN 'SEP'
							WHEN 10 THEN 'OCT'
							WHEN 11 THEN 'NOV'
							WHEN 12 THEN 'DEC'
						END

	RETURN @monthName


END

GO



/****** Object:  StoredProcedure [dbo].[ESE_DataAnalyzer]  Script Date: 02/21/2009 21:43:12 GMT ******/
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ESE_DataAnalyzer]') AND type in (N'P', N'PC'))
BEGIN
	DROP PROCEDURE [ESE_DataAnalyzer]
END

/****** Object:  StoredProcedure [dbo].[ESE_DataAnalyzer]    Script Date: 09/23/2010 20:10:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROCEDURE:	[ESE_DataAnalyzer]
-- CREATED:		02/21/2009
-- BY:			Doug Perez
-- DESCRIPTION:	Pulls applicable web log data for COUNTER and publisher
--				reporting and integrates publishers offline data within NetInsight
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[ESE_DataAnalyzer] 
	@Profile					VARCHAR(128),
	@ReportStartDate 			DATETIME = NULL, 	-- Optional
	@ReportEndDate				DATETIME = NULL, 	-- Optional
	@Suspend_PageViews			BIT = NULL,			-- Optional
	@Suspend_Sessionization		BIT = NULL,			-- Optional
	@Suspend_COUNTER			BIT = NULL,			-- Optional
	@Suspend_NetInsightParms	BIT = NULL,			-- Optional
	@Suspend_ArchiveData		BIT = NULL,			-- Optional
	@Suspend_Product_NI			BIT = NULL,			-- Optional
	@Suspend_Platform_NI		BIT = NULL,			-- Optional
	@Suspend_PageType_NI		BIT = NULL,			-- Optional
	@Suspend_COUNTER_NI			BIT = NULL,			-- Optional
	@Suspend_ProdType_NI		BIT = NULL,			-- Optional
	@Suspend_PbYear_NI			BIT = NULL,			-- Optional
	@Suspend_PbMonthDay_NI		BIT = NULL,			-- Optional
	@Suspend_Archive_NI			BIT = NULL,			-- Optional
	@Suspend_Supplier_NI		BIT = NULL,			-- Optional
	@Suspend_Authors_NI			BIT = NULL,			-- Optional
	@Suspend_PrintDate_NI		BIT = NULL,			-- Optional
	@Suspend_FPorArtID_NI		BIT = NULL,			-- Optional
	@Suspend_OnlineDate_NI		BIT = NULL,			-- Optional
	@Suspend_ContType_NI		BIT = NULL,			-- Optional
	@Suspend_OITaxonomy_NI		BIT = NULL,			-- Optional
	@Suspend_AdvAccDate_NI		BIT = NULL,			-- Optional
	@Suspend_IssorSupp_NI		BIT = NULL,			-- Optional
	@Suspend_IssCovDate_NI		BIT = NULL,			-- Optional
	@Suspend_ConVolume_NI		BIT = NULL,			-- Optional
	@Suspend_ConLastPg_NI		BIT = NULL,			-- Optional
	@Suspend_ProdTax_NI			BIT = NULL,			-- Optional
	@Suspend_site_NI			BIT = NULL,			-- Optional
	@Suspend_SubStatus_NI		BIT = NULL,			-- Optional
	@Suspend_SubType_NI			BIT = NULL,			-- Optional
	@Suspend_AcctType_NI		BIT = NULL,			-- Optional
	@Override_Profile			VARCHAR(128) = NULL	-- Optional
AS

	-- Variable Declaration
	DECLARE @SQL 				VARCHAR(8000)
	DECLARE @NSQL				NVARCHAR(4000)

	DECLARE @Min_ViewID			INT
	DECLARE @Max_ViewID			INT
	
	DECLARE @RowCount			BIGINT

	-- Initialize Variables
	IF @Suspend_PageViews IS NULL 
		SET @Suspend_PageViews = 0
	IF @Suspend_Sessionization IS NULL 
		SET @Suspend_Sessionization = 0
	IF @Suspend_COUNTER IS NULL 
		SET @Suspend_COUNTER = 0
	IF @Suspend_NetInsightParms IS NULL 
		SET @Suspend_NetInsightParms = 0
	IF @Suspend_ArchiveData IS NULL 
		SET @Suspend_ArchiveData = 0
	IF @Suspend_Product_NI	 IS NULL 
		SET @Suspend_Product_NI	 = 0
	IF @Suspend_Platform_NI IS NULL 
		SET @Suspend_Platform_NI = 0
	IF @Suspend_PageType_NI IS NULL 
		SET @Suspend_PageType_NI = 0
	IF @Suspend_COUNTER_NI IS NULL 
		SET @Suspend_COUNTER_NI = 0
	IF @Suspend_ProdType_NI IS NULL 
		SET @Suspend_ProdType_NI = 0
	IF @Suspend_PbYear_NI IS NULL 
		SET @Suspend_PbYear_NI = 0
	IF @Suspend_PbMonthDay_NI IS NULL 
		SET @Suspend_PbMonthDay_NI = 0
	IF @Suspend_Archive_NI IS NULL 
		SET @Suspend_Archive_NI = 0
	IF @Suspend_Supplier_NI IS NULL 
		SET @Suspend_Supplier_NI = 0
	IF @Suspend_Authors_NI IS NULL 
		SET @Suspend_Authors_NI = 0
	IF @Suspend_PrintDate_NI IS NULL 
		SET @Suspend_PrintDate_NI = 0
	IF @Suspend_FPorArtID_NI IS NULL 
		SET @Suspend_FPorArtID_NI = 0
	IF @Suspend_OnlineDate_NI IS NULL 
		SET @Suspend_OnlineDate_NI = 0
	IF @Suspend_ContType_NI IS NULL 
		SET @Suspend_ContType_NI = 0
	IF @Suspend_OITaxonomy_NI IS NULL 
		SET @Suspend_OITaxonomy_NI = 0
	IF @Suspend_AdvAccDate_NI IS NULL 
		SET @Suspend_AdvAccDate_NI = 0
	IF @Suspend_IssorSupp_NI IS NULL 
		SET @Suspend_IssorSupp_NI = 0
	IF @Suspend_IssCovDate_NI IS NULL 
		SET @Suspend_IssCovDate_NI = 0
	IF @Suspend_ConVolume_NI IS NULL 
		SET @Suspend_ConVolume_NI = 0
	IF @Suspend_ConLastPg_NI IS NULL 
		SET @Suspend_ConLastPg_NI = 0
	IF @Suspend_ProdTax_NI IS NULL 
		SET @Suspend_ProdTax_NI = 0
	IF @Suspend_site_NI IS NULL 
		SET @Suspend_site_NI = 0
	IF @Suspend_SubStatus_NI IS NULL 
		SET @Suspend_SubStatus_NI = 0
	IF @Suspend_SubType_NI IS NULL 
		SET @Suspend_SubType_NI = 0
	IF @Suspend_AcctType_NI IS NULL 
		SET @Suspend_AcctType_NI = 0



	-- Log Start
	EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_DataAnalyzer', 'BEGIN', 0


	-- Create Data Table if needed
	IF @Suspend_PageViews = 0		
	BEGIN
		-- Create ESEData table for profile if it does not exist in the client's database
		SET @SQL = 'EXEC ESE_Create_ESEData ' + @Profile
		EXEC (@SQL)
	END
	
	-- Determine range of data to be processed - Date Range Parameters
	IF @ReportStartDate IS NOT NULL OR @ReportEndDate IS NOT NULL
	BEGIN

 		-- Retrieve Minimum ViewID From Profile Views Table
		IF @ReportStartDate IS NOT NULL
		BEGIN

			SET @NSQL = N'SELECT @Min_ViewID = MIN(ViewID)
				FROM [dbo].[' + @Profile + '_Views] ' +
				'WHERE ViewDateTime >= ' + char(39) + CAST(@ReportStartDate AS VARCHAR(50)) + char(39)	
			EXEC sp_executesql 
				@query = @NSQL, 
				@params = N'@Min_ViewID INT OUTPUT', 
				@Min_ViewID = @Min_ViewID OUTPUT
		END

 		-- Retrieve Maximum ViewID From Profile Views Table
		IF @ReportEndDate IS NOT NULL
		BEGIN
			SET @NSQL = N'SELECT @Max_ViewID = MAX(ViewID)
				FROM [dbo].[' + @Profile + '_Views] ' +
				'WHERE ViewDateTime <= ' + char(39) + CAST(@ReportEndDate AS VARCHAR(50)) + char(39)	
			EXEC sp_executesql 
				@query = @NSQL, 
				@params = N'@Max_ViewID INT OUTPUT', 
				@Max_ViewID = @Max_ViewID OUTPUT
		END
	END	
	ELSE		
	BEGIN
		-- Check to see if it is a partial rerun
		IF @Suspend_PageViews = 1
		BEGIN

			-- Get Minimum ViewID value from data table
			SET @NSQL = N'SELECT @Min_ViewID = MIN(ViewID)
				FROM [dbo].[' + @Profile + 'Data] ' 
			EXEC sp_executesql 
				@query = @NSQL, 
				@params = N'@Min_ViewID INT OUTPUT', 
				@Min_ViewID = @Min_ViewID OUTPUT

			-- Get Maximum ViewID value from data table
			SET @NSQL = N'SELECT @Max_ViewID = MAX(ViewID)
				FROM [dbo].[' + @Profile + 'Data] ' 
			EXEC sp_executesql 
				@query = @NSQL, 
				@params = N'@Max_ViewID INT OUTPUT', 
				@Max_ViewID = @Max_ViewID OUTPUT

			-- Get ReportStartDate value from data table
			SET @NSQL = N'SELECT @ReportStartDate = MIN(ViewDateTime)
				FROM [dbo].[' + @Profile + 'Data] ' 
			EXEC sp_executesql 
				@query = @NSQL, 
				@params = N'@ReportStartDate DATETIME OUTPUT', 
				@ReportStartDate = @ReportStartDate OUTPUT

			-- Get ReportEndDate value from data table
			SET @NSQL = N'SELECT @ReportEndDate = MAX(ViewDateTime)
				FROM [dbo].[' + @Profile + 'Data] ' 
			EXEC sp_executesql 
				@query = @NSQL, 
				@params = N'@ReportEndDate DATETIME OUTPUT', 
				@ReportEndDate = @ReportEndDate OUTPUT

		END
		ELSE
		BEGIN
			-- Get ReportStartDate value - Automated Nightly Processing
			SELECT @ReportStartDate = DATEADD(second, 1, MAX(LogEndDate))
				FROM ESELogProcess 
				WHERE LogProfile = @Profile AND (LogErrNum IS NULL OR LogErrNum = 0)

			-- Get Minimum ViewID value - Automated Nightly Processing
			SET @NSQL = N'SELECT @Min_ViewID = MIN(ViewID)
				FROM [dbo].[' + @Profile + '_Views]  
				WHERE ViewDateTime >= ' + char(39) + CAST(@ReportStartDate AS VARCHAR(50)) + char(39)	
			EXEC sp_executesql 
				@query = @NSQL, 
				@params = N'@Min_ViewID INT OUTPUT', 
				@Min_ViewID = @Min_ViewID OUTPUT
		END
	END
	
	-- Set Minimum ViewID and ReportStartDate values if NULL
	IF @Min_ViewID IS NULL 
		SET @Min_ViewID = 1
	IF @ReportStartDate IS NULL 
	BEGIN
		SET @NSQL = N'SELECT @ReportStartDate = MIN(ViewDateTime)
			FROM [dbo].[' + @Profile + '_Views] ' 
		EXEC sp_executesql 
			@query = @NSQL, 
			@params = N'@ReportStartDate DATETIME OUTPUT', 
			@ReportStartDate = @ReportStartDate OUTPUT
	END

	-- Set Maximum ViewID and ReportEndDate values if NULL
	IF @Max_ViewID IS NULL
	BEGIN
		SET @NSQL = N'SELECT @Max_ViewID = MAX(ViewID)
			FROM [dbo].[' + @Profile + '_Views]' 
		EXEC sp_executesql 
			@query = @NSQL, 
			@params = N'@Max_ViewID INT OUTPUT', 
			@Max_ViewID = @Max_ViewID OUTPUT
	END
	IF @ReportEndDate IS NULL
	BEGIN
		SET @NSQL = N'SELECT @ReportEndDate = MAX(ViewDateTime)
			FROM [dbo].[' + @Profile + '_Views]' 
		EXEC sp_executesql 
			@query = @NSQL, 
			@params = N'@ReportEndDate DATETIME OUTPUT', 
			@ReportEndDate = @ReportEndDate OUTPUT
	END

	-- Exception to account start date exceeding end date (due to a manual run)
	IF @ReportStartDate > @ReportEndDate
	BEGIN
		SET @NSQL = N'SELECT @ReportStartDate = MAX(ViewDateTime)
			FROM [dbo].[' + @Profile + 'DataArchive] ' 
		EXEC sp_executesql 
			@query = @NSQL, 
			@params = N'@ReportStartDate DATETIME OUTPUT', 
			@ReportStartDate = @ReportStartDate OUTPUT
	END

	-- Process If There Is Data
	IF (@ReportStartDate IS NOT NULL AND @ReportEndDate IS NOT NULL) AND (@ReportStartDate <= @ReportEndDate)
	BEGIN

		IF @Suspend_PageViews = 0		
		BEGIN

			-- Truncate Data Table for New Run
			SET @SQL = 
				'TRUNCATE TABLE ' + @Profile + 'Data'
			EXEC (@SQL)

			-- Populate ESEData table with Application Page Views for target profile

			IF @Override_Profile IS NULL 
			BEGIN
				SET @SQL = 
					'EXEC ' + @Profile + '_Insert_PageViews ' 
						+ @Profile + ', ' + char(39) +
						+ CAST(@ReportStartDate AS VARCHAR(50)) + char(39) + ', ' + char(39) +
						+ CAST(@ReportEndDate AS VARCHAR(50)) + char(39) + ', '
						+ CAST(@Suspend_PageViews AS VARCHAR(1))
				EXEC (@SQL)
			END
			ELSE
			BEGIN
				SET @SQL = 
					'EXEC ' + @Override_Profile + '_Insert_PageViews ' 
						+ @Profile + ', ' + char(39) +
						+ CAST(@ReportStartDate AS VARCHAR(50)) + char(39) + ', ' + char(39) +
						+ CAST(@ReportEndDate AS VARCHAR(50)) + char(39) + ', '
						+ CAST(@Suspend_PageViews AS VARCHAR(1))
				EXEC (@SQL)
			END
		END

		-- Update Sessionization Informaiton in ESEData table for target profile
		IF @Suspend_Sessionization = 0
		BEGIN
			IF @Override_Profile IS NULL
			BEGIN
				SET @SQL = 
					'EXEC ' + @Profile + '_Update_Sessionization ' 
						+ @Profile
				EXEC (@SQL)
			END
			ELSE
			BEGIN
				SET @SQL = 
					'EXEC ' + @Override_Profile + '_Update_Sessionization ' 
						+ @Profile
				EXEC (@SQL)
			END
		END



		-- Update COUNTER Informaiton in ESEData table for target profile (double-click rule)
		IF @Suspend_COUNTER = 0
		BEGIN
			EXEC ESE_Update_COUNTER @Profile
		END

		-- Populate JournalPage Tables if Activated
		IF @Suspend_ArchiveData = 0
		BEGIN
			SET @SQL = 
				'DELETE FROM ' + @Profile + 'DataArc WHERE ViewID IN (SELECT ViewID FROM ' + @Profile + 'Data) ' +
				'INSERT INTO ' + @Profile + 'DataArc (ViewDateTime, PageID, HostID, VisitID, ViewID, UserID, SiteID, SiteID2, SiteID3, 
				Product, EventType, PageType, ReqYear, ReqMonth, Platform, HostIP, HostNum, COUNTER, PageCode, ProductID, PbMonthDay, 
				PbYear, ProdType, Archive, Supplier, ISBN, DOI)
				SELECT ViewDateTime, PageID, HostID, VisitID, ViewID, UserID, SiteID, SiteID2, SiteID3, Product, EventType, PageType, 
				ReqYear, ReqMonth, Platform, HostIP, HostNum, COUNTER, PageCode, ProductID, PbMonthDay, PbYear, ProdType, Archive, Supplier, ISBN, DOI
				FROM ' + @Profile + 'Data'
			EXEC (@SQL)
			EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_DataAnalyzer', 'Insert Into Data Archive Table', @@ROWCOUNT
		END

		-- Populate NetInsight Parameter Tables if Activated
		IF @Suspend_NetInsightParms = 0
		BEGIN
			EXEC ESE_Update_NetInsightParms 
				@Profile, 
				@Suspend_COUNTER_NI,
				@Suspend_PageType_NI,
				@Suspend_Platform_NI,
				@Suspend_Product_NI,
				@Suspend_ProdType_NI,
				@Suspend_PbYear_NI,
				@Suspend_PbMonthDay_NI,
				@Suspend_Archive_NI,
				@Suspend_Supplier_NI,
				@Suspend_Authors_NI,
				@Suspend_PrintDate_NI,
				@Suspend_FPorArtID_NI,
				@Suspend_OnlineDate_NI,
				@Suspend_ContType_NI,
				@Suspend_OITaxonomy_NI,
				@Suspend_AdvAccDate_NI,
				@Suspend_IssorSupp_NI,
				@Suspend_IssCovDate_NI,
				@Suspend_ConVolume_NI,
				@Suspend_ConLastPg_NI,
				@Suspend_ProdTax_NI,
				@Suspend_site_NI,
				@Suspend_SubStatus_NI,
				@Suspend_SubType_NI,
				@Suspend_AcctType_NI
		END


		-- Get Count of Rows in ESEData Table
		IF @ReportStartDate IS NOT NULL AND @ReportEndDate IS NOT NULL 
		BEGIN
			SET @NSQL = N'SELECT @RowCount = COUNT(ViewID)
				FROM [dbo].[' + @Profile + 'Data] ' 
			EXEC sp_executesql 
				@query = @NSQL, 
				@params = N'@RowCount INT OUTPUT', 
				@RowCount = @RowCount OUTPUT
		END
	END
	ELSE
	BEGIN
		SET @RowCount = 0
		EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_DataAnalyzer', 'No Data Available', 0
	END

	-- Log Process Run
	EXEC [ESE_Insert_LogProcess] @Profile, 'ESE_DataAnalyzer', 
		@ReportStartDate, @ReportEndDate, 
		@Min_ViewID, @Max_ViewID, @RowCount

	-- Log End
	EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_DataAnalyzer', 'END', 0


GO





IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ESE_Update_COUNTER]') AND type in (N'P', N'PC'))
BEGIN
	DROP PROCEDURE [ESE_Update_COUNTER]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROCEDURE:	[ESE_Update_COUNTER]
-- CREATED:		02/23/09
-- BY:			Doug Perez
-- DESC:		Updates COUNTER Field in ESEData table for profile (mark double-clicks)  
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[ESE_Update_COUNTER]
	@Profile					VARCHAR(128),
	@Suspend_COUNTER			BIT = NULL			-- Optional
AS
BEGIN

	-- Declare Variables
	DECLARE @SQL AS VARCHAR(8000)
	
	-- Initialize Variables
	IF @Suspend_COUNTER IS NULL 
		SET @Suspend_COUNTER = 0

	-- Log Start
	EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_Update_COUNTER', 'BEGIN', 0



	-- Create Helper Index
	CREATE NONCLUSTERED INDEX [IDX_COUNTERSupport]
	ON [dbo].[oupData] ([EventType])
	INCLUDE ([PageID],[VisitID],[ViewID],[ViewDateTime])


	-- Update ESEData table with COUNTER information if enabled
	IF @Suspend_COUNTER = 0
	BEGIN

		-- Set COUNTER field to NULL
		SET @SQL = 'UPDATE ' + @Profile + 'Data SET COUNTER = NULL'
		EXEC (@SQL)

		-- Update Double-clicks
		SET @SQL = 
			'UPDATE ' + @Profile + 'Data SET COUNTER = ''Double-Click'' FROM ' + @Profile + 'Data ' +
			'WHERE ViewID IN (' + 
			'SELECT DISTINCT V2.ViewID FROM ' + @Profile + 'Data V INNER JOIN ' +
			@Profile + 'Data V2 ON V2.ViewDateTime <= V.ViewDateTime AND ' + 
			'V2.ViewDateTime >= DATEADD(s,-10,V.ViewDateTime) and V2.VisitID = V.VisitID AND ' +
			'V2.PageID = V.PageID and V2.ViewID < V.ViewID ' +
			'WHERE V.EventType NOT LIKE ''%.pdf'' AND (V.EventType IS NOT NULL OR V.PageType IS NOT NULL)'

		SELECT @SQL = @SQL + ' UNION ' +
			'SELECT DISTINCT V2.ViewID FROM ' + @Profile + 'Data V INNER JOIN ' +
			@Profile + 'Data V2 ON V2.ViewDateTime <= V.ViewDateTime AND ' + 
			'V2.ViewDateTime >= DATEADD(s,-30,V.ViewDateTime) and V2.VisitID = V.VisitID AND ' +
			'V2.ArticleID = V.ArticleID and V2.ViewID < V.ViewID ' +
			'WHERE LOWER(V.EventType) LIKE ''%pdf%'' OR LOWER(V.PageType) LIKE ''%pdf%'' )'
		EXEC (@SQL)
		
		-- Update COUNTER 
		SET @SQL = 
			'UPDATE ' + @Profile + 'Data SET COUNTER = ''Compliant'' FROM ' + @Profile + 'Data ' +
			'WHERE COUNTER IS NULL AND (EventType IS NOT NULL OR PageType IS NOT NULL)' 
		EXEC (@SQL)
	END
	EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_Update_COUNTER', 'Update COUNTER', @@ROWCOUNT
	
	-- Drop Helper Index
	DROP INDEX oupData.IDX_COUNTERSupport

	-- Log End
	EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_Update_COUNTER', 'END', 0
END

GO







/****** Object:  StoredProcedure [dbo].[ESE_Update_NetInsightParms]   Script Date: 02/23/2009 21:08:28 GMT ******/
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ESE_Update_NetInsightParms]') AND type in (N'P', N'PC'))
BEGIN
	DROP PROCEDURE [ESE_Update_NetInsightParms]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROCEDURE:	[ESE_Update_NetInsightParms]
-- CREATED:		02/23/09
-- BY:			Doug Perez
-- DESC:		Updates NetInsight Parameters based on data in ESEData table for profile   
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[ESE_Update_NetInsightParms]
	@Profile					VARCHAR(128),
	@Suspend_Product			BIT = NULL,			-- Optional
	@Suspend_Platform			BIT = NULL,			-- Optional
	@Suspend_PageType			BIT = NULL,			-- Optional
	@Suspend_COUNTER			BIT = NULL,			-- Optional
	@Suspend_ProdType			BIT = NULL,			-- Optional
	@Suspend_PbYear				BIT = NULL,			-- Optional
	@Suspend_PbMonthDay			BIT = NULL,			-- Optional
	@Suspend_Archive			BIT = NULL,			-- Optional
	@Suspend_Supplier			BIT = NULL,			-- Optional
	@Suspend_Authors			BIT = NULL,			-- Optional
	@Suspend_PrintDate			BIT = NULL,			-- Optional
	@Suspend_FPorArtID			BIT = NULL,			-- Optional
	@Suspend_OnlineDate			BIT = NULL,			-- Optional
	@Suspend_ContType			BIT = NULL,			-- Optional
	@Suspend_OITaxonomy			BIT = NULL,			-- Optional
	@Suspend_AdvAccDate			BIT = NULL,			-- Optional
	@Suspend_IssorSupp			BIT = NULL,			-- Optional
	@Suspend_IssCovDate			BIT = NULL,			-- Optional
	@Suspend_ConVolume			BIT = NULL,			-- Optional
	@Suspend_ConLastPg			BIT = NULL,			-- Optional
	@Suspend_ProdTax			BIT = NULL,			-- Optional
	@Suspend_site				BIT = NULL,			-- Optional
	@Suspend_SubStatus			BIT = NULL,			-- Optional
	@Suspend_SubType			BIT = NULL,			-- Optional
	@Suspend_AcctType			BIT = NULL			-- Optional


AS

	-- Log Start
	EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_Update_NetInsightParms', 'BEGIN', 0

	-------------------------------------------------------------------------------------- 
	-- Update NetInsight EventType Parameter with data in ESEData table for target profile
	-------------------------------------------------------------------------------------- 

	-- Initialize Variables
	IF @Suspend_COUNTER IS NULL 
		SET @Suspend_COUNTER = 0
	IF @Suspend_PageType IS NULL 
		SET @Suspend_PageType = 0
	IF @Suspend_Platform IS NULL 
		SET @Suspend_Platform = 0
	IF @Suspend_Product IS NULL 
		SET @Suspend_Product = 0
	IF @Suspend_ProdType IS NULL 
		SET @Suspend_ProdType = 0
	IF @Suspend_PbYear IS NULL 
		SET @Suspend_PbYear = 0
	IF @Suspend_PbMonthDay IS NULL 
		SET @Suspend_PbMonthDay = 0
	IF @Suspend_Archive IS NULL 
		SET @Suspend_Archive = 0
	IF @Suspend_Supplier IS NULL 
		SET @Suspend_Supplier = 0
	IF @Suspend_Authors IS NULL 
		SET @Suspend_Authors = 0
	IF @Suspend_PrintDate IS NULL 
		SET @Suspend_PrintDate = 0
	IF @Suspend_FPorArtID IS NULL 
		SET @Suspend_FPorArtID = 0
	IF @Suspend_OnlineDate IS NULL 
		SET @Suspend_OnlineDate = 0
	IF @Suspend_ContType IS NULL 
		SET @Suspend_ContType = 0
	IF @Suspend_OITaxonomy IS NULL 
		SET @Suspend_OITaxonomy = 0
	IF @Suspend_AdvAccDate IS NULL 
		SET @Suspend_AdvAccDate = 0
	IF @Suspend_IssorSupp IS NULL 
		SET @Suspend_IssorSupp = 0
	IF @Suspend_IssCovDate IS NULL 
		SET @Suspend_IssCovDate = 0
	IF @Suspend_ConVolume IS NULL 
		SET @Suspend_ConVolume = 0
	IF @Suspend_ConLastPg IS NULL 
		SET @Suspend_ConLastPg = 0
	IF @Suspend_ProdTax IS NULL 
		SET @Suspend_ProdTax = 0
	IF @Suspend_site IS NULL 
		SET @Suspend_site = 0
	IF @Suspend_SubStatus IS NULL 
		SET @Suspend_SubStatus = 0
	IF @Suspend_SubType IS NULL 
		SET @Suspend_SubType = 0
	IF @Suspend_AcctType IS NULL 
		SET @Suspend_AcctType = 0


	IF @Suspend_COUNTER = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'COUNTER'
	IF @Suspend_PageType = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'PageType'
	IF @Suspend_Platform = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'Platform'
	IF @Suspend_Product = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'Product'
	IF @Suspend_ProdType = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'ProdType'
	IF @Suspend_PbYear = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'PbYear'
	IF @Suspend_PbMonthDay = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'PbMonthDay'
	IF @Suspend_Archive = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'Archive'
	IF @Suspend_Supplier = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'Supplier'
	IF @Suspend_Authors = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'Authors'
	IF @Suspend_PrintDate = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'PrintDate'
	IF @Suspend_FPorArtID = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'FPorArtID'
	IF @Suspend_OnlineDate = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'OnlineDate'
	IF @Suspend_ContType = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'ContType'
	IF @Suspend_OITaxonomy = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'OITaxonomy'
	IF @Suspend_AdvAccDate = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'AdvAccDate'
	IF @Suspend_IssorSupp = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'IssorSupp'
	IF @Suspend_IssCovDate = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'IssCovDate'
	IF @Suspend_ConVolume = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'ConVolume'
	IF @Suspend_ConLastPg = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'ConLastPg'
	IF @Suspend_ProdTax = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'ProdTax'
	IF @Suspend_site = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'site'
	IF @Suspend_SubStatus = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'SubStatus'
	IF @Suspend_SubType = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'SubType'
	IF @Suspend_AcctType = 0
		EXEC ESE_Insert_NetInsightParameter @Profile, 'AcctType'



	-- Log End
	EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_Update_NetInsightParms', 'END', 0
GO


/****** Object:  StoredProcedure [dbo].[ESE_Insert_NetInsightParameter]   Script Date: 02/23/2009 23:23:28 GMT ******/
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ESE_Insert_NetInsightParameter]') AND type in (N'P', N'PC'))
BEGIN
	DROP PROCEDURE [ESE_Insert_NetInsightParameter]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROCEDURE:	[ESE_Insert_NetInsightParameter]
-- CREATED:		02/23/09
-- BY:			Doug Perez
-- DESC:		Insert Data from ESEData table for profile into Defined NetInsight Parameter
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[ESE_Insert_NetInsightParameter]
	@Profile					VARCHAR(128),
	@Parameter	 				VARCHAR(128)
AS

BEGIN

	DECLARE @SQL AS VARCHAR(8000)
	DECLARE @Temp AS VARCHAR(128)

	-------------------------------------------------------------------------------------- 
	-- Update Defined NetInsight Parameter with data in ESEData table for target profile
	-------------------------------------------------------------------------------------- 

	-- Create Indexes for Performance Optimization
	SET @Temp = @Parameter + ' - Create Index'
	SET @SQL = 
		'CREATE INDEX [IX_' + @Profile + 'Data_' + @Parameter + '] ON 
		[dbo].['+ @Profile +'Data]([' + @Parameter + '])'
	EXEC (@SQL)
	EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_Insert_NetInsightParameter', @Temp, 0

	-- Insert distinct parm values into key table (be sure this table is set to auto-increment!!)
	SET @SQL = 
		'INSERT INTO ' + @Profile + '_P_' + @Parameter + 'ID (P_' + @Parameter + ') ' +
			'SELECT DISTINCT [' + @Parameter + '] ' + 
			'FROM ' + @Profile + 'Data ' +
			'WHERE [' + @Parameter + '] NOT IN (SELECT DISTINCT P_' + @Parameter + ' FROM ' + @Profile + '_P_' + @Parameter + 'ID) ' +
				'AND [' + @Parameter + '] IS NOT NULL' 
	EXEC (@SQL)

	-- Delete existing records based on viewid range and insert new records
	SET @SQL = 
		'DELETE FROM ' + @Profile + '_P_' + @Parameter + ' WHERE ViewID IN (SELECT ViewID FROM ' + @Profile + 'Data) ' +
		'INSERT INTO ' + @Profile + '_P_' + @Parameter + '(ViewID, P_' + @Parameter + 'ID) ' +
			'SELECT DISTINCT ViewID, P_' + @Parameter + 'ID ' +
			'FROM ' + @Profile + 'Data ap ' +
				'INNER JOIN ' + @Profile + '_P_' + @Parameter + 'ID pp ON ap.[' + @Parameter + '] = P_' + @Parameter --+ ' ' +
-- 04/07/2010 - GVO:  Removed on account table contains records for each page view by a robot or spider that has the parameter
--		'DELETE FROM ' + @Profile + '_SP_' + @Parameter + ' WHERE ViewID IN (SELECT ViewID FROM ' + @Profile + 'Data) ' +
--		'INSERT INTO ' + @Profile + '_SP_' + @Parameter + '(ViewID, P_' + @Parameter + 'ID) ' +
--			'SELECT DISTINCT ViewID, P_' + @Parameter + 'ID ' +
--			'FROM ' + @Profile + 'Data ap ' +
--				'INNER JOIN ' + @Profile + '_P_' + @Parameter + 'ID pp ON ap.[' + @Parameter + '] = P_' + @Parameter 
	EXEC (@SQL)

	EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_Insert_NetInsightParameter', @Parameter, @@ROWCOUNT

	SET @Temp = @Parameter + ' - Drop Index'
	SET @SQL =
		'DROP INDEX ' + @Profile + 'Data.IX_' + @Profile + 'Data_' + @Parameter
	EXEC (@SQL)

	EXEC [ESE_Insert_LogEvent] @Profile, 'ESE_Insert_NetInsightParameter', @Temp, 0
END
GO


-- **************************************************************************************************************************
-- **************************************************************************************************************************
--	OUP RELATED OBJECTS DOWN BELOW
-- **************************************************************************************************************************
-- **************************************************************************************************************************



/****** Object:  StoredProcedure [dbo].[oup_Insert_PageViews]   Script Date: 02/22/2009 22:26:28 GMT ******/
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[oup_Insert_PageViews]') AND type in (N'P', N'PC'))
BEGIN
	DROP PROCEDURE [oup_Insert_PageViews]
END

/****** Object:  StoredProcedure [dbo].[oup_Insert_PageViews]    Script Date: 4/10/2014 12:38:57 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROCEDURE:	[oup_Insert_PageViews]
-- CREATED:		08/11/09
-- BY:			Doug Perez
-- DESC:		Inserts PageViews into data table for oup
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[oup_Insert_PageViews]
	@Profile					VARCHAR(128),
	@ReportStartDate			DATETIME,
	@ReportEndDate				DATETIME,
	@Suspend_PageViews			BIT = NULL			-- Optional
AS
BEGIN

	DECLARE @SQL AS VARCHAR(8000)

	-- Initialize Variables
	IF @Suspend_PageViews IS NULL 
		SET @Suspend_PageViews = 0

	-- Log Start
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'BEGIN', 0


	-- Pull data from NetInsight tables if enabled
	IF @Suspend_PageViews = 0
	BEGIN

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>> oup LOGIC START <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

		-- Insert unprocessed data into daily processing table
		SET @SQL = '
		INSERT INTO ' + @Profile + 'Data  (PageID, HostID, VisitID, ViewID, ViewDateTime, EventType, ReqYear, ReqMonth, Page, 
			PageBreakdown, UserID, HostNum, HostIP)
		SELECT vw.PageID, hid.HostID, vw.VisitID, vw.ViewID, vw.ViewDateTime, SUBSTRING(P_EventType, 1, 120), YEAR(vw.ViewDateTime), MONTH(vw.ViewDateTime),
			dbo.ESE_Get_Page(Page) AS Page, dbo.ESE_Get_PageBreakdown(Page) AS PageBreakdown, vs.UserID, 
			dbo.ESE_Get_HostNum(hid.Host) AS HostNum, hid.Host
		FROM ' + @Profile + '_Views vw
			INNER JOIN ' + @Profile + '_Visits vs on vw.VisitID = vs.VisitID
			INNER JOIN ' + @Profile + '_HostID hid on vs.HostID = hid.HostID
			INNER JOIN ' + @Profile + '_PageID pid on pid.PageID = vw.PageID
			LEFT JOIN ' + @Profile + '_P_EventType pt on pt.ViewID = vw.ViewID
			LEFT JOIN ' + @Profile + '_P_EventTypeID ptid on ptid.P_EventTypeID = pt.P_EventTypeID
		WHERE vw.ViewDateTime BETWEEN ' + char(39) + CAST(@ReportStartDate AS VARCHAR(50)) + char(39) + 
			' AND ' + char(39) + CAST(@ReportEndDate AS VARCHAR(50)) + char(39)
		EXEC (@SQL)
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Insert Page Views - Page Tags', @@ROWCOUNT

		-- Update Platform / Product using Journal Feed
		UPDATE d
		SET  Product = SUBSTRING(p.product_name, 1, 155),
			[Platform] = 'Oxford Journals'
		FROM oupData d
			INNER JOIN oupProducts p ON LOWER(SUBSTRING(Page, 8, PATINDEX('%/%', SUBSTRING(Page, 8, LEN(Page))) - 1)) = 
				LOWER(REPLACE(p.URL, '/', ''))
		WHERE LOWER(product_type) = 'journal' AND LEN(Page) > 7
			AND PATINDEX('%/%', SUBSTRING(Page, 8, LEN(Page))) > 0
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product from Journals Feed', @@ROWCOUNT


		-- Update Platform/Product using details of sites feed
		UPDATE oupData
		SET Supplier = SUBSTRING(sd.supplier, 1, 50)
			,[Platform] = 
				CASE WHEN [Platform] IS NULL AND LOWER(sd.supplier) <> 'highwire' THEN SUBSTRING(sd.product, 1, 128)
				ELSE [Platform] END,
			[site] = SUBSTRING(sd.product, 1, 255)
		FROM oupData d
			INNER JOIN oupSite_Details sd ON 'http://' + LOWER(SUBSTRING(Page, 8, PATINDEX('%/%', SUBSTRING(Page, 8, LEN(Page))) - 1)) + '/'
			=  	LOWER(live_URL)
		WHERE live_URL IS NOT NULL
			AND LEN(Page) > 7
			AND PATINDEX('%/%', live_URL) > 0
			AND SUBSTRING(REVERSE(live_URL), 1, 1) = '/'
			AND PATINDEX('%/%', SUBSTRING(Page, 8, LEN(Page))) > 0
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Platform/Product from LiveURL', @@ROWCOUNT


		-- Update Platform / Product from details of sites feed (Loose Join)
		UPDATE d
		SET  Supplier = SUBSTRING(sd.supplier, 1, 50), 
			[Platform] = 
				CASE WHEN [Platform] IS NULL AND LOWER(sd.supplier) <> 'highwire' THEN SUBSTRING(sd.product, 1, 128)
				ELSE [Platform] END,
			d.[site] = SUBSTRING(sd.product, 1, 255)
		FROM oupData d
			INNER JOIN oupSite_Details sd ON d.Page LIKE '%' + REPLACE(live_URL, 'http://', '') + '%'
		WHERE live_URL IS NOT NULL
			AND LEN(Page) > 7
			AND PATINDEX('%/%', live_URL) > 0
			AND Supplier IS NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform Using Details of Sites Feed (Loose Join)', @@ROWCOUNT

		-- Update Platform / Product from details of sites feed (Product Join)
		UPDATE oupData SET  Supplier = SUBSTRING(sd.supplier, 1, 50), 
				            [Platform] = 
								CASE WHEN [Platform] IS NULL AND LOWER(sd.supplier) <> 'highwire' THEN SUBSTRING(sd.product, 1, 128)
								ELSE [Platform] END,
							[site] = SUBSTRING(sd.product, 1, 255)
		FROM oupData dt 
		INNER JOIN oupSite_Details sd ON sd.product = dt.Product
		WHERE Supplier IS NULL AND Product IS NOT NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform Using Details of Sites Feed (Product Join)', @@ROWCOUNT


		-- Update Platform / Product from details of sites feed - Oxford Bibliographies
		UPDATE d
		SET  Supplier = 'Safari', 
			 [Platform] = 'Oxford Bibliographies',
			 Product = 'Oxford Bibliographies'
		--SELECT TOP 100 *
		FROM oupData d
		WHERE lower(d.[Page]) LIKE '%oxfordbibliographies.com%'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for Oxford Bibliographies', @@ROWCOUNT


		-- Update Platform / Product from Journal Feed (Loose Join)
		UPDATE d
		SET  Product = SUBSTRING(p.product_name, 1, 155), [Platform] = 'Oxford Journals'
		FROM oupData d
			INNER JOIN oupProducts p ON d.[Page] LIKE '%' + REPLACE(p.URL, '/', '') + '%'
		WHERE LOWER(Supplier) = 'highwire' AND LOWER(product_type) = 'journal'
			AND Product IS NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform Using Journals Feed (Loose Join)', @@ROWCOUNT

		--Update Platform for ODNB and BFL
		UPDATE d
		SET [Platform] = CASE WHEN svid.[Server] = 'ODNB' THEN 'Oxford Dictionary of National Biography'
							  WHEN svid.[Server] LIKE '%BFL%' THEN 'Berg Fashion Library'
							  END
		FROM oupData d
		JOIN oup_Views v
			ON d.ViewID = v.ViewID
		JOIN oup_ServerID svid
			ON v.ServerID = svid.ServerID
		WHERE svid.[Server] = 'ODNB'
		OR svid.[Server] IN ('BFL1','BFL2')
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Platform for ODNB and BFL', @@ROWCOUNT


		--Update Event Type for ODNB/BFL
		UPDATE d
		SET d.EventType = 'FULLTEXT_HTML'
		FROM oupData d
		JOIN oup_Views v
			ON d.ViewID = v.ViewID
		JOIN oup_ServerID svid
			ON v.ServerID = svid.ServerID
		WHERE svid.[Server] IN ('ODNB')  --,'BFL1','BFL2'
		AND (LOWER(d.[Page]) LIKE '%/view/%'
		  OR LOWER(d.[Page]) LIKE '%/browse/getalife%'
		  OR LOWER(d.[Page]) LIKE '%/public/themes/%[0-9].html%')
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update EventType for ODNB', @@ROWCOUNT

	
		-- Update PageType Field
		UPDATE oupData
		SET PageType =  
		CASE 
			WHEN LOWER(EventType) = 'login-' THEN 'login'
			WHEN LOWER(EventType) = 'restricted' THEN 'turnaway'
			WHEN REPLACE(REPLACE(REPLACE(LOWER(EventType),'-', '') ,'_', ''),'.','') LIKE '%login%' THEN REPLACE(REPLACE(REPLACE(REPLACE(LOWER(EventType),'-', '') ,'_', ''),'.',''),'login','') + ' - login'
			ELSE REPLACE(REPLACE(REPLACE(LOWER(EventType),'-', '') ,'_', ''),'.','')
		END
		FROM oupData
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageType', @@ROWCOUNT

		-- Update PageType Field
		UPDATE oupData
		SET PageType =  
		CASE 
			WHEN LOWER(EventType) = 'login-' THEN 'login'
			WHEN LOWER(EventType) = 'restricted' THEN 'turnaway'
			WHEN EventType = 'ABSTRACT' THEN 'section request'
			WHEN EventType LIKE 'FULLTEXT_HTML%' THEN 'section request'
			WHEN LOWER(EventType) = 'dictionary_entry' THEN 'section request'
			WHEN EventType = 'NO_RESULTS' THEN 'search'
			WHEN LOWER(EventType) IN ('restricted', 'login-full-text', 'login-full-text.pdf', 'login-full-text-lowres.pdf') THEN 'turnaway'
			WHEN EventType = 'abstract' THEN 'abstract'
			WHEN LOWER(EventType) like '%search%' THEN 'search'
			WHEN EventType = 'turnaway' THEN 'turnaway'
			WHEN EventType = 'full-text' THEN 'fulltext'
			WHEN EventType = 'fulltexthtml' THEN 'fulltexthtml'
			WHEN EventType = 'full-text.pdf' THEN 'fulltextpdf'
			WHEN LOWER(EventType) IN ('table_of_contents', 'toc', 'table-of-contents') THEN 'table of contents'
			WHEN REPLACE(REPLACE(REPLACE(LOWER(EventType),'-', '') ,'_', ''),'.','') LIKE '%login%' THEN REPLACE(REPLACE(REPLACE(REPLACE(LOWER(EventType),'-', '') ,'_', ''),'.',''),'login','') + ' - login'
			ELSE REPLACE(REPLACE(REPLACE(LOWER(EventType),'-', '') ,'_', ''),'.','')
		END
		FROM oupData
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageType', @@ROWCOUNT



		-- Update PageType and PageCode for Semantico products
		UPDATE d
		SET d.PageType = CASE WHEN t.ViewID IS NULL THEN 'section request'
							  ELSE 'turnaway'
							  END
		FROM oupData d
		LEFT JOIN oup_P_TurnawayID t
			ON d.ViewID = t.ViewID
		WHERE d.PageType IS NULL
		AND (LOWER(d.[Page]) LIKE '%www.oxfordartonline.com%/article%'
			 OR
			 LOWER(d.[Page]) LIKE '%www.oxfordmusiconline.com%/article%')
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageType/PageCode (Semantico)', @@ROWCOUNT

		-- Update Turnaways for Safari WHERE turnaway_id = 'NO_SUBSCRIPTION_TO_CONTENT'
		UPDATE d
		SET d.PageType = 'turnaway'
		FROM oupData d
		JOIN oup_P_TurnawayID t
			ON d.ViewID = t.ViewID
		JOIN oup_P_TurnawayIDID tid
			ON t.P_TurnawayIDID = tid.P_TurnawayIDID
		WHERE d.Supplier = 'Safari'
		AND tid.P_TurnawayID = 'NO_SUBSCRIPTION_TO_CONTENT'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Turnaways (Safari)', @@ROWCOUNT

		-- Update PageCode Field for Semantico Search Results
		UPDATE oupData
		SET PageType = 'search'
		WHERE (LOWER([Page]) LIKE '%www.oxfordartonline.com%'
		OR LOWER([Page]) LIKE '%www.oxfordmusiconline.com%')
		AND LOWER([Page]) LIKE '%/search_results%'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageType OAO and OMO Searches (Semantico)', @@ROWCOUNT

		--Update OED Searches
		UPDATE oupData
		SET PageType = 'search'
		WHERE LOWER([Page]) LIKE '%www.oed.com%redirectedfrom='
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageType OED Searches', @@ROWCOUNT

		--Update PageType for ODNB Turnaways
		UPDATE d
		SET d.PageType = CASE WHEN otaid.P_ODNBTrnAwy = 'login' THEN 'turnaway'
							  WHEN otaid.P_ODNBTrnAwy = 'license' THEN 'turnaway - sub exceeded' 
						 END
		FROM oupData d
		JOIN oup_Views v
			ON d.ViewID = v.ViewID
		JOIN oup_ServerID svid
			ON v.ServerID = svid.ServerID
		JOIN oup_P_ODNBTrnAwy ota WITH(NOLOCK)
			ON da.ViewID = ota.ViewID
		JOIN oup_P_ODNBTrnAwyID otaid WITH(NOLOCK)
			ON ota.P_ODNBTrnAwyID = otaid.P_ODNBTrnAwyID
		WHERE svid.[Server] IN ('ODNB')  --,'BFL1','BFL2'	
		AND otaid.P_ODNBTrnAwy IN ('login','license')
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update ODNB Turnaways', @@ROWCOUNT

		--Update PageType for ODNB Searches
		UPDATE d
		SET d.PageType = 'search'
		FROM oupData d
		JOIN oup_Views v
			ON d.ViewID = v.ViewID
		JOIN oup_ServerID svid
			ON v.ServerID = svid.ServerID
		WHERE svid.[Server] IN ('ODNB')  --,'BFL1','BFL2'	
		AND (LOWER(d.[Page]) LIKE '%/search/articles%'
		  OR LOWER(d.[Page]) LIKE '%/search/quick%'
		  OR LOWER(d.[Page]) LIKE '%/search/refine%'
		  OR LOWER(d.[Page]) LIKE '%/search/refs%')
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update ODNB Searches', @@ROWCOUNT
	
		-- Update PageCode Field using PageType
		UPDATE oupData
		SET PageCode =  
		CASE 
			WHEN LOWER(PageType) IN ('fulltext', 'fulltexthtml', 'fulltextpdf') THEN 'F'
			WHEN LOWER(PageType) = 'abstract' THEN 'A'
			WHEN LOWER(PageType) IN ('search', 'quicksearch') THEN 'S'
			WHEN LOWER(PageType) IN ('table of contents', 'toc') THEN 'T'
			WHEN LOWER(PageType) = 'turnaway' THEN 'X'
			WHEN LOWER(PageType) = 'section request' THEN 'B'
		END
		FROM oupData
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageCode - PageType', @@ROWCOUNT

		-- Update PageType Field for Result Clicks (Safari)
		UPDATE oupData
		SET PageType =  PageType + ' - result click'
		FROM oupData dt 
		WHERE LOWER(PageBreakdown) LIKE '%result=%'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageType for Result Clicks (Safari)', @@ROWCOUNT

		-- Update PageType Field for Result Clicks 2 (Safari)
		UPDATE oupData
		SET PageType =  PageType + ' - result click'
		FROM oupData dt
			INNER JOIN oup_Views vw ON vw.ViewID = dt.ViewID
		WHERE [Platform] = 'Safari' 
			AND (SELECT PageCode FROM oupData dt2 WHERE dt2.ViewID = vw.PrevViewID) = 'S'
			AND PageCode <> 'S'
			AND PageType NOT LIKE '%result click%'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageType for Result Clicks 2 (Safari)', @@ROWCOUNT

		-- Update PageType Field for Result Clicks (Semantico)
		UPDATE oupData
		SET PageType =  PageType + ' - result click'
		FROM oupData dt
			INNER JOIN oup_Views vw ON vw.ViewID = dt.ViewID
		WHERE (SELECT PageCode FROM oupData dt2 WHERE dt2.ViewID = vw.PrevViewID) = 'S'
			AND PageCode <> 'S'
			AND PageType NOT LIKE '%result click%'
			AND (LOWER(dt.[Page]) LIKE '%www.oxfordartonline.com%' OR LOWER(dt.[Page]) LIKE '%www.oxfordmusiconline%')
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageType for Result Clicks (Semantico)', @@ROWCOUNT

		-- Update PageType Field for Result Clicks (OBSO, AASC, OISO)
		UPDATE oupData
		SET PageType =  PageType + ' - result click'
		FROM oupData dt 
		WHERE LOWER(PageBreakdown) LIKE '%pos=%'
		AND (LOWER([Page]) LIKE '%www.oxfordbiblicalstudies.com%'
		  OR LOWER([Page]) LIKE '%www.oxfordaasc.com%'
		  OR LOWER([Page]) LIKE '%www.oxfordislamicstudies.com%')
		AND LEN(PageType + ' - result click') <= 120
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageType for Result Clicks (Safari)', @@ROWCOUNT


		-- Filter out turnaway requests based on turnaway id = SUB_EXCEEDED
		UPDATE oupData
		SET PageType = PageType + ' - sub exceeded' 
		FROM oupData dt
			INNER JOIN oup_P_TurnawayID trn ON trn.ViewID = dt.ViewID	
			INNER JOIN oup_P_TurnawayIDID trnid on trn.P_TurnawayIDID = trnid.P_TurnawayIDID
		WHERE P_TurnawayID IN ('SUB_EXCEEDED', '1') AND PageCode = 'X'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update PageCode to NULL for SUB_EXCEEDED Turnways', @@ROWCOUNT

		-- Update Product Information using DOI (Highwire Holdings feed)
		UPDATE oupData
		SET Product = 
				CASE WHEN Product IS NULL THEN SUBSTRING(product_name, 1, 155)
				ELSE Product END,
			ProductID = P_DOI,
			[Platform] = 'Oxford Journals',
			ProdType = 
			CASE 
				WHEN LOWER(hh.[type]) like '%article%' and hh.openaccess = 'yes' THEN 'Journals - Open Access' 
				WHEN LOWER(hh.[type]) like '%article%' and hh.openaccess <> 'yes' THEN 'Journals' 
				ELSE SUBSTRING(hh.[type],1, 128) 
			END,
			Archive = 
			CASE 
				WHEN DATEPART(yyyy, coverdate) <= 1995 AND hh.archive_years LIKE '%' + CAST(DATEPART(YYYY, ViewDateTime) AS VARCHAR(4)) + '%' THEN 'Archive'
				ELSE 'Not Archive'
			END,
			PbYear = SUBSTRING(hh.yearpublished, 1, 4)
		FROM  oupData d
			INNER JOIN oup_P_DOI doi ON d.ViewID = doi.ViewID
			INNER JOIN oup_P_DOIID doiid ON doi.P_DOIID = doiid.P_DOIID
			INNER JOIN oupHighwire_Holdings hh ON LOWER(hh.doi) = LOWER(doiid.P_DOI)
			INNER JOIN oupProducts pd ON pd.product_id = hh.journal_id	
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information - Highwire Holdings Feed', @@ROWCOUNT



		-- Update Product Information with DOI (metadata feed)
		UPDATE oupData
		SET Product = 
				CASE WHEN Product IS NULL THEN SUBSTRING(parentTitle, 1, 155)
				ELSE Product END,
			ProductID = P_DOI,
			ProdType = 
			CASE 
				WHEN md.[type] = 'Book' THEN 'Books' 
				WHEN md.[type] = 'Journal Article' and md.openAccessStatus = 'Open Access' THEN 'Journals - Open Access'
				WHEN md.[type] = 'Journal Article' and (md.openAccessStatus <> 'Open Access' OR md.openAccessStatus IS NULL) THEN 'Journals' 
				ELSE SUBSTRING(md.[type], 1, 128) 
			END
			,PrintDate = md.printPubDate
			,FPorArtID = md.firstPage
			,OnlineDate = md.onlinePubDate
			,ContType = md.[type]
			,AdvAccDate = CASE WHEN md.ahead_of_print = 1 THEN md.onlinePubDate ELSE NULL END
			,IssorSupp = md.issue
			,IssCovDate = md.printPubDate
			,ConVolume = md.volume
			,ConLastPg = md.lastPage
			,ProdTax = 'UNKNOWN'
			-- NEED TO SET ARCHIVE FIELD ONCE OUP UPDATES METADATA FEED TO INCLUDE ARCHIVE INDICATORS
			,PbYear = SUBSTRING(md.volumeYear, 1, 4)
			-- Commented out for performance on 2/13/2013 - DP
			--,PbMonthDay = CASE WHEN CHARINDEX('-', SUBSTRING(md.onlinePubDate, CHARINDEX('-', md.onlinePubDate) + 1, LEN(md.onlinePubDate))) = 0
			--					THEN ''
			--				ELSE RIGHT(md.onlinePubDate, 2) + '-'
			--				END +
			--				CASE WHEN CHARINDEX('-', md.onlinePubDate) = 0
			--					THEN ''
			--				WHEN CHARINDEX('-', SUBSTRING(md.onlinePubDate, CHARINDEX('-', md.onlinePubDate) + 1, LEN(md.onlinePubDate))) = 0
			--					THEN dbo.getMonthShortName(CAST(SUBSTRING(md.onlinePubDate, CHARINDEX('-', md.onlinePubDate) + 1, LEN(md.onlinePubDate)) AS INT)) 
			--				ELSE dbo.getMonthShortName(CAST(LEFT(SUBSTRING(md.onlinePubDate, CHARINDEX('-', md.onlinePubDate) + 1, LEN(md.onlinePubDate)), CHARINDEX('-', SUBSTRING(md.onlinePubDate, CHARINDEX('-', md.onlinePubDate) + 1, LEN(md.onlinePubDate))) - 1) AS INT))
			--				END
		FROM  oupData d
			INNER JOIN oup_P_DOI doi ON d.ViewID = doi.ViewID
			INNER JOIN oup_P_DOIID doiid ON doi.P_DOIID = doiid.P_DOIID
			INNER JOIN oupMetadata md ON LOWER(md.doi) = LOWER(doiid.P_DOI)
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (HW) - metadata feed', @@ROWCOUNT



		-- Update UNKNOWN Information based on DOI
		UPDATE oupData
		SET Product = 
			CASE 
				WHEN Product IS NULL THEN 'UNKNOWN'
				ELSE Product
			END,
			ProdType = 
			CASE 
				WHEN ProdType IS NULL THEN 'UNKOWN'
				ELSE ProdType
			END,
			PbYear = 
			CASE
				WHEN PbYear IS NULL THEN 'UNKNOWN'
				ELSE PbYear
			END,
			PbMonthDay = 
			CASE
				WHEN PbMonthDay IS NULL THEN 'UNKNOWN'
				ELSE PbMonthDay
			END,
			Archive = 
			CASE 
				WHEN Archive IS NULL THEN 'UNKNOWN'
				ELSE Archive
			END,
			[Platform] = 
			CASE 
				WHEN [Platform] IS NULL THEN 'UNKNOWN'
				ELSE [Platform]
			END
		FROM oupData d
			INNER JOIN oup_P_DOI doi ON doi.ViewID = d.ViewID
			INNER JOIN oup_P_DOIID doiid ON doi.P_DOIID = doiid.P_DOIID
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (HW) - UNKNOWN', @@ROWCOUNT


		-- Update ProductID for books with ISBN using Parm 
		UPDATE oupData 
		SET ProductID = P_ISBN, ISBN = P_ISBN
		FROM oupData d
			INNER JOIN oup_P_ISBN isbn ON isbn.ViewID = d.ViewID
			INNER JOIN oup_P_ISBNID isbnid on isbn.P_ISBNID = isbnid.P_ISBNID
		WHERE PageCode IN ('B', 'X')  
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update ProductID for Books with ISBN using Parm (Safari)', @@ROWCOUNT

		-- Update ProductID for books with ISBN using URL (workaround for the above issue)
		UPDATE oupData 
		SET ProductID = SUBSTRING(d.Page, PATINDEX('%/9%', d.Page)+ 1, 13), ISBN = SUBSTRING(d.Page, PATINDEX('%/9%', d.Page)+ 1, 13)
		FROM oupData d
		WHERE PageCode IN ('B', 'X') AND PATINDEX('%/9%', d.Page) > 0 AND ProductID IS NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update ProductID for Books with ISBN using URL (Safari)', @@ROWCOUNT

		-- Update ProductID for books with ISBN using URL (variation 2)
		UPDATE oupData 
		SET ProductID = SUBSTRING(d.Page, PATINDEX('%978%', d.Page), 13), ISBN = SUBSTRING(d.Page, PATINDEX('%978%', d.Page), 13)
		FROM oupData d
		WHERE PageCode IN ('B', 'X') AND PATINDEX('%978%', d.Page) > 0 AND ProductID IS NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update ProductID for Books with ISBN using URL (Safari)', @@ROWCOUNT


		-- Update ProductID for books with ISBN using URL (variation 2)
		UPDATE oupData 
		SET ProductID = SUBSTRING(d.Page, PATINDEX('%978%', d.Page), 13), ISBN = SUBSTRING(d.Page, PATINDEX('%978%', d.Page), 13)
		FROM oupData d
			INNER JOIN oup_P_SrcTitID sr ON sr.ViewID = d.ViewID
			INNER JOIN oup_P_SrcTitIDID srid ON sr.P_SrcTitIDID = srid.P_SrcTitIDID
		WHERE PageCode IN ('B', 'X') AND ProductID IS NULL
			AND LEN(SUBSTRING(P_SrcTitID, PATINDEX('%/978%', P_SrcTitID) + 1, 13)) >= 13
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update ProductID for Books with ISBN using SrcTit parm (Safari)', @@ROWCOUNT

		--Gather records for next series of updates
		SELECT *
		INTO #data
		FROM oupData
		WHERE PageCode IN ('B','X')
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Stage records for next series of updates', @@ROWCOUNT

		CREATE CLUSTERED INDEX #ix_data_ProductID ON #data(ProductID)


		-- Update Book Information based on ISBN in URL (Part 1)
		UPDATE d
		SET Product = SUBSTRING(parentTitle, 1, 155)
		FROM  #data d
			  INNER JOIN oupMetadata md ON d.ProductID = md.printISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed (Part 1)', @@ROWCOUNT

		-- Update Book Information based on ISBN in URL (Part 2)
		UPDATE d
		SET [Platform] = SUBSTRING(productTitle, 1,128)
		FROM  #data d
			  INNER JOIN oupMetadata md ON d.ProductID = md.printISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed (Part 2)', @@ROWCOUNT

		-- Update Book Information based on ISBN in URL (Part 3)
		UPDATE d
		SET   DOI = 
		CASE 
					WHEN [type] = 'Book' THEN md.doi
					ELSE NULL
			  END
		FROM  #data d
		INNER JOIN oupMetadata md ON d.ProductID = md.printISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed (Part 3)', @@ROWCOUNT

		-- Update Book Information based on ISBN in URL (Part 4)
		UPDATE d
		SET  AdvAccDate = CASE WHEN md.ahead_of_print = 1 THEN md.onlinePubDate ELSE NULL END
		FROM  #data d
			  INNER JOIN oupMetadata md ON d.ProductID = md.printISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed (Part 4)', @@ROWCOUNT

		-- Update Book Information based on ISBN in URL (Part 6)
		UPDATE d
		SET PbYear = SUBSTRING(md.onlinePubDate, 1, 4)
		FROM  #data d
			  INNER JOIN oupMetadata md ON d.ProductID = md.printISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed (Part 6)', @@ROWCOUNT

		-- Update Book Information based on ISBN in URL (Part 7)
		UPDATE d
		SET ProdType = md.[type]
			  ,PrintDate = md.printPubDate
			  ,FPorArtID = md.firstPage
			  ,OnlineDate = md.onlinePubDate
			  ,ContType = md.[type]
			  ,IssorSupp = md.issue
			  ,IssCovDate = md.printPubDate
			  ,ConVolume = md.volume
			  ,ConLastPg = md.lastPage
			  ,ProdTax = 'UNKNOWN'
		FROM  #data d
			  INNER JOIN oupMetadata md ON d.ProductID = md.printISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed (Part 7)', @@ROWCOUNT


		-- Update Book Information based on onlineISBN in URL (Part 1)
		UPDATE d
		SET Product = SUBSTRING(parentTitle, 1, 155)
		FROM  #data d
			  INNER JOIN oupMetadata md ON d.ProductID = md.onlineISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed onlineISBN (Part 1)', @@ROWCOUNT

		-- Update Book Information based on onlineISBN in URL (Part 2)
		UPDATE d
		SET [Platform] = SUBSTRING(productTitle, 1,128)
		FROM  #data d
			  INNER JOIN oupMetadata md ON d.ProductID = md.onlineISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed onlineISBN (Part 2)', @@ROWCOUNT

		-- Update Book Information based on onlineISBN in URL (Part 3)
		UPDATE d
		SET   DOI = 
		CASE 
					WHEN [type] = 'Book' THEN md.doi
					ELSE NULL
			  END
		FROM  #data d
		INNER JOIN oupMetadata md ON d.ProductID = md.onlineISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed onlineISBN (Part 3)', @@ROWCOUNT

		-- Update Book Information based on onlineISBN in URL (Part 4)
		UPDATE d
		SET  AdvAccDate = CASE WHEN md.ahead_of_print = 1 THEN md.onlinePubDate ELSE NULL END
		FROM  #data d
			  INNER JOIN oupMetadata md ON d.ProductID = md.onlineISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed onlineISBN (Part 4)', @@ROWCOUNT

		-- Update Book Information based on onlineISBN in URL (Part 6)
		UPDATE d
		SET PbYear = SUBSTRING(md.onlinePubDate, 1, 4)
		FROM  #data d
			  INNER JOIN oupMetadata md ON d.ProductID = md.onlineISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed onlineISBN (Part 6)', @@ROWCOUNT

		-- Update Book Information based on ISBN in URL (Part 7)
		UPDATE d
		SET ProdType = md.[type]
			  ,PrintDate = md.printPubDate
			  ,FPorArtID = md.firstPage
			  ,OnlineDate = md.onlinePubDate
			  ,ContType = md.[type]
			  ,IssorSupp = md.issue
			  ,IssCovDate = md.printPubDate
			  ,ConVolume = md.volume
			  ,ConLastPg = md.lastPage
			  ,ProdTax = 'UNKNOWN'
		FROM  #data d
			  INNER JOIN oupMetadata md ON d.ProductID = md.onlineISBN
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - metadata feed onlineISBN (Part 7)', @@ROWCOUNT

		UPDATE d
		SET  d.Product = t.Product
			,d.[Platform] = t.[Platform]
			,d.DOI = t.DOI
			,d.AdvAccDate = t.AdvAccDate
			,d.PbYear = t.PbYear
			,d.ProdType = t.ProdType
			,d.PrintDate = t.PrintDate
			,d.FPorArtID = t.FPorArtID
			,d.OnlineDate = t.OnlineDate
			,d.ContType = t.ContType
			,d.IssorSupp = t.IssorSupp
			,d.IssCovDate = t.IssCovDate
			,d.ConVolume = t.ConVolume
			,d.ConLastPg = t.ConLastPg
			,d.ProdTax = t.ProdTax
		FROM oupData d
		JOIN #data t
			ON d.ViewID = t.ViewID
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Records using Staging Table', @@ROWCOUNT

		--Clean up temp table
		DROP TABLE #data
		

		-- Update UNKNOWN Information based on Books
		UPDATE oupData
		SET Product = 
			CASE 
				WHEN Product IS NULL THEN 'UNKNOWN'
				ELSE Product
			END,
			ProdType = 
			CASE 
				WHEN ProdType IS NULL THEN 'UNKOWN'
				ELSE ProdType
			END,
			PbYear = 
			CASE
				WHEN PbYear IS NULL THEN 'UNKNOWN'
				ELSE PbYear
			END,
			PbMonthDay = 
			CASE
				WHEN PbMonthDay IS NULL THEN 'UNKNOWN'
				ELSE PbMonthDay
			END,
			Archive = 
			CASE 
				WHEN Archive IS NULL THEN 'UNKNOWN'
				ELSE Archive
			END,
			[Platform] = 
			CASE 
				WHEN [Platform] IS NULL THEN 'UNKNOWN'
				ELSE [Platform]
			END
		FROM oupData d
			INNER JOIN oupMetadata md ON d.ProductID = md.printISBN 
		WHERE PageCode IN ('B', 'X')
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product Information (Safari) - UNKNOWN', @@ROWCOUNT


	--UPDATE NetInsight parameters from Metadata feed - DOI Match
	UPDATE d
	SET  d.Authors = c.fullName
		,d.OITaxonomy = mot.oiTaxonomy
	FROM oupData d
	INNER JOIN oupMetadata m
		ON d.ProductID = m.doi
	LEFT JOIN oupMetadata_oiTaxonomyList mol
		ON m.metadata_Id = mol.metadata_Id
	LEFT JOIN oupMetadata_oiTaxonomy mot
		ON mol.oiTaxonomyList_Id = mot.oiTaxonomyList_Id
	LEFT JOIN oupMetadata_ContributorList cl
		ON m.metadata_Id = cl.metadata_Id
	LEFT JOIN oupMetadata_Contributor c
		ON cl.contributorList_Id = c.contributorList_Id
	WHERE d.PageCode IS NOT NULL
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update NetInsight Parameters - DOI Match', @@ROWCOUNT


	--Update Taxonomy parameter from Metadata feed - PrintISBN Match
	UPDATE d
	SET  d.OITaxonomy = mot.oiTaxonomy
	FROM oupData d
	INNER JOIN oupMetadata m
		ON d.ProductID = m.printISBN
	INNER JOIN oupMetadata_oiTaxonomyList mol
		ON m.metadata_Id = mol.metadata_Id
	INNER JOIN oupMetadata_oiTaxonomy mot
		ON mol.oiTaxonomyList_Id = mot.oiTaxonomyList_Id
	WHERE d.PageCode IS NOT NULL
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update NetInsight Parameters (Taxonomy) - Print ISBN Match', @@ROWCOUNT

	--Update Authors parameter from Metadata feed - PrintISBN Match
	UPDATE d
	SET  d.Authors = c.fullName
	FROM oupData d
	INNER JOIN oupMetadata m
		ON d.ProductID = m.printISBN
	INNER JOIN oupMetadata_ContributorList cl
		ON m.metadata_Id = cl.metadata_Id
	INNER JOIN oupMetadata_Contributor c
		ON cl.contributorList_Id = c.contributorList_Id
	WHERE d.PageCode IS NOT NULL
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update NetInsight Parameters (Authors) - Print ISBN Match', @@ROWCOUNT


	--Update Taxonomy parameter from Metadata feed - onlineISBN Match
	UPDATE d
	SET  d.OITaxonomy = mot.oiTaxonomy
	FROM oupData d
	INNER JOIN oupMetadata m
		ON d.ProductID = m.onlineISBN
	INNER JOIN oupMetadata_oiTaxonomyList mol
		ON m.metadata_Id = mol.metadata_Id
	INNER JOIN oupMetadata_oiTaxonomy mot
		ON mol.oiTaxonomyList_Id = mot.oiTaxonomyList_Id
	WHERE d.PageCode IS NOT NULL
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update NetInsight Parameters (Taxonomy) - onlineISBN Match', @@ROWCOUNT

	--Update Authors parameter from Metadata feed - onlineISBN Match
	UPDATE d
	SET  d.Authors = c.fullName
	FROM oupData d
	INNER JOIN oupMetadata m
		ON d.ProductID = m.onlineISBN
	INNER JOIN oupMetadata_ContributorList cl
		ON m.metadata_Id = cl.metadata_Id
	INNER JOIN oupMetadata_Contributor c
		ON cl.contributorList_Id = c.contributorList_Id
	WHERE d.PageCode IS NOT NULL
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update NetInsight Parameters (Authors) - onlineISBN Match', @@ROWCOUNT

	-- Update ProductID to NULL for Oxford Bibliographies to ensure usage falls on one line
	UPDATE oupData SET ISBN = NULL, ProductID = NULL, Product = 'Oxford Bibliographies'
	FROM oupData
	WHERE LOWER([Page]) LIKE '%oxfordbibliographies.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update NetInsight Parameters - Set ProductID to NULL for OBO', @@ROWCOUNT

	-- Catch OBO entries from different URL's
	UPDATE oupData
	SET Product = 'Oxford Bibliographies'
	WHERE Product <> 'Oxford Bibliographies'
	AND [Platform] = 'Oxford Bibliographies'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product for Oxford Bibliographies from Other URLs', @@ROWCOUNT


	-- Update Platform / Product for OED (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Oxford English Dictionary',
			Product = 'Oxford English Dictionary',
			ProductID = '9780198605553',
			ISBN = '9780198605553'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE lower(d.[Page]) LIKE '%oed.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for OED (Oxford English Dictionary)', @@ROWCOUNT

	-- Update Platform / Product for ODO (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'IDM', 
			[Platform] = 'Oxford Dictionaries',
			Product = 'Oxford Dictionaries',
			ProductID = '9780199558490',
			ISBN = '9780199558490'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE lower(d.[Page]) LIKE '%oxforddictionaries.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for ODO (Oxford Dictionaries)', @@ROWCOUNT


	-- Update Platform / Product for LPF - Investment Claims (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Investment Claims',
			Product = 'Investment Claims' ,
			ProductID = '9780199230907',
			ISBN = '9780199230907'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE LOWER(d.[Page]) LIKE '%oxia.ouplaw.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for LPF - Investment Claims', @@ROWCOUNT

	-- Update Platform / Product for LPF - Oxford Competition Law (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Oxford Competition Law',
			Product = 'Oxford Competition Law',
			ProductID = '9780199586998',
			ISBN = '9780199586998'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE LOWER(d.[Page]) LIKE '%oxcat.ouplaw.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for LPF - Oxford Competition Law', @@ROWCOUNT

	-- Update Platform / Product for LPF - Oxford Constitutions of the World (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Oxford Constitutions of the World',
			Product = 'Oxford Constitutions of the World',
			ProductID = '9780199799848', 
			ISBN = '9780199799848'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE LOWER(d.[Page]) LIKE '%oxcon.ouplaw.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for LPF - Oxford Constitutions of the World', @@ROWCOUNT

	-- Update Platform / Product for LPF - Oxford Public International Law (Hard-coded Values & Parameter Data)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Oxford Public International Law',
			Product = CASE WHEN cpid.P_contentpdt = 'epil' THEN 'Max Planck Encyclopedia of Public International Law'
						WHEN cpid.P_contentpdt = 'osail' THEN 'Oxford Scholarly Authorities on International Law'
						WHEN cpid.P_contentpdt = 'oril' THEN CASE WHEN cmid.P_contentmod = 'ihrl' THEN 'ORIL - International Human Rights Law'
																	WHEN cmid.P_contentmod = 'ildc' THEN 'ORIL - International Law in Domestic Courts'
																	WHEN cmid.P_contentmod = 'iic' THEN 'ORIL - International Investment Claims'
																	WHEN cmid.P_contentmod = 'icgj' THEN 'ORIL - International Courts of General Jurisdiction'
																	WHEN cmid.P_contentmod = 'icl' THEN 'ORIL - International Criminal Law'
																END
					END,
			ProductID = CASE WHEN cpid.P_contentpdt = 'epil' THEN '9780199231690'
						WHEN cpid.P_contentpdt = 'osail' THEN '9780199603114'
						WHEN cpid.P_contentpdt = 'oril' THEN CASE WHEN cmid.P_contentmod = 'ihrl' THEN '9780199533664'
																	WHEN cmid.P_contentmod = 'ildc' THEN '9780199297122'
																	WHEN cmid.P_contentmod = 'iic' THEN '9780199566617'
																	WHEN cmid.P_contentmod = 'icgj' THEN '9780199547838'
																	WHEN cmid.P_contentmod = 'icl' THEN '9780199533695'
																END
				   END,
			ISBN = CASE WHEN cpid.P_contentpdt = 'epil' THEN '9780199231690'
						WHEN cpid.P_contentpdt = 'osail' THEN '9780199603114'
						WHEN cpid.P_contentpdt = 'oril' THEN CASE WHEN cmid.P_contentmod = 'ihrl' THEN '9780199533664'
																	WHEN cmid.P_contentmod = 'ildc' THEN '9780199297122'
																	WHEN cmid.P_contentmod = 'iic' THEN '9780199566617'
																	WHEN cmid.P_contentmod = 'icgj' THEN '9780199547838'
																	WHEN cmid.P_contentmod = 'icl' THEN '9780199533695'
																END
				   END
	--SELECT TOP 100 *
	FROM oupData d
	INNER JOIN oup_P_contentpdt cp
		ON d.ViewID = cp.ViewID
	INNER JOIN oup_P_contentpdtID cpid
		ON cp.P_contentpdtID = cpid.P_contentpdtID
	LEFT JOIN oup_P_contentmod cm
		ON d.ViewID = cm.ViewID
	LEFT JOIN oup_P_contentmodID cmid
		ON cm.P_contentmodID = cmid.P_contentmodID
	WHERE LOWER(d.[Page]) LIKE '%opil.ouplaw.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for LPF - Oxford Public International Law', @@ROWCOUNT



	END
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'END', 0

	-- Update Platform / Product for OHWM - Oxford History of Western Music (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Oxford History of Western Music',
			Product = 'Oxford History of Western Music' ,
			ProductID = '9780199773572',
			ISBN = '9780199773572'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE LOWER(d.[Page]) LIKE '%www.oxfordwesternmusic.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for OHWM - Oxford History of Western Music', @@ROWCOUNT

	-- Update Platform / Product for OBSO - Oxford Biblical Studies Online (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Oxford Biblical Studies Online',
			Product = 'Oxford Biblical Studies Online' ,
			ProductID = '9780195341119',
			ISBN = '9780195341119'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE LOWER(d.[Page]) LIKE '%www.oxfordbiblicalstudies.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for OBSO - Oxford Biblical Studies Online', @@ROWCOUNT

	--Have to catch OBSO products where the platform was assigned through a different URL
	UPDATE oupData
	SET Product = 'Oxford Biblical Studies Online', ProductID = '9780195341119'
	WHERE [Platform] = 'Oxford Biblical Studies Online'
	AND Product <> 'Oxford Biblical Studies Online'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product OBSO - Oxford Biblical Studies Online (Other URLs)', @@ROWCOUNT

	-- Update Platform / Product for AASC - Oxford African American Studies Center (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Oxford African American Studies Center',
			Product = 'Oxford African American Studies Center' ,
			ProductID = '9780195301731',
			ISBN = '9780195301731'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE LOWER(d.[Page]) LIKE '%www.oxfordaasc.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for AASC - Oxford African American Studies Center', @@ROWCOUNT

	-- Update Platform / Product for OISO - Oxford Islamic Studies Online (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Oxford Islamic Studies Online',
			Product = 'Oxford Islamic Studies Online' ,
			ProductID = '9780195301748',
			ISBN = '9780195301748',
			[site] = 'Oxford Islamic Studies Online'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE LOWER(d.[Page]) LIKE '%www.oxfordislamicstudies.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for OISO - Oxford Islamic Studies Online', @@ROWCOUNT

	-- Update Platform / Product for Who's Who (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Who''s Who',
			Product = 'Who''s Who' ,
			ProductID = '9780199540884',
			ISBN = '9780199540884',
			[site] = 'Who''s Who'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE LOWER(d.[Page]) LIKE '%www.ukwhoswho.com%'
	AND LOWER(d.[Page]) LIKE '%/whoswho/%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform Who''s Who', @@ROWCOUNT

	-- Update Platform / Product for Who Was Who (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Who Was Who',
			Product = 'Who Was Who' ,
			ProductID = '9780195301731',
			ISBN = '9780195301731',
			[site] = 'Who Was Who'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE LOWER(d.[Page]) LIKE '%www.ukwhoswho.com%'
	AND LOWER(d.[Page]) LIKE '%/whowaswho/%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for Who Was Who', @@ROWCOUNT

	--Format Who Was Who 
	UPDATE oupData
	SET  Product = 'Who Was Who'
		,ProductID = '9780195301731'
	WHERE [Platform] = 'Who Was Who'
	AND (Product <> 'Who Was Who' OR ProductID <> '9780195301731')
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / ProductID for Who Was Who (Catch All)', @@ROWCOUNT

	-- Update Platform / Product for OLDO - Oxford Language Dictionaries Online (Hard-coded Values)
	UPDATE d
	SET  Supplier = 'Safari', 
			[Platform] = 'Oxford Language Dictionaries Online',
			Product = CASE WHEN d.PageBreakdown LIKE '%oldo/b-en-zh%' THEN 'Oxford Language Dictionaries Online - Chinese'
						   WHEN d.PageBreakdown LIKE '%oldo/b-fr-en%' THEN 'Oxford Language Dictionaries Online - French'
						   WHEN d.PageBreakdown LIKE '%oldo/b-de-en%' THEN 'Oxford Language Dictionaries Online - German'
						   WHEN d.PageBreakdown LIKE '%oldo/b-it-en%' THEN 'Oxford Language Dictionaries Online - Italian'
						   WHEN d.PageBreakdown LIKE '%oldo/b-ru-en%' THEN 'Oxford Language Dictionaries Online - Russian'
						   WHEN d.PageBreakdown LIKE '%oldo/b-es-en%' THEN 'Oxford Language Dictionaries Online - Spanish'
						   ELSE 'Oxford Language Dictionaries Online - Language Web'
						   END,
			ProductID = CASE WHEN d.PageBreakdown LIKE '%oldo/b-en-zh%' THEN '9780199532230'
						   WHEN d.PageBreakdown LIKE '%oldo/b-fr-en%' THEN '9780199532247'
						   WHEN d.PageBreakdown LIKE '%oldo/b-de-en%' THEN '9780199532254'
						   WHEN d.PageBreakdown LIKE '%oldo/b-it-en%' THEN '9780199532261'
						   WHEN d.PageBreakdown LIKE '%oldo/b-ru-en%' THEN '9780199532278'
						   WHEN d.PageBreakdown LIKE '%oldo/b-es-en%' THEN '9780199532285'
						   ELSE '9780198608899'
						   END,
			ISBN = CASE WHEN d.PageBreakdown LIKE '%oldo/b-en-zh%' THEN '9780199532230'
						   WHEN d.PageBreakdown LIKE '%oldo/b-fr-en%' THEN '9780199532247'
						   WHEN d.PageBreakdown LIKE '%oldo/b-de-en%' THEN '9780199532254'
						   WHEN d.PageBreakdown LIKE '%oldo/b-it-en%' THEN '9780199532261'
						   WHEN d.PageBreakdown LIKE '%oldo/b-ru-en%' THEN '9780199532278'
						   WHEN d.PageBreakdown LIKE '%oldo/b-es-en%' THEN '9780199532285'
						   ELSE '9780198608899'
						   END,
			[site] = 'Oxford Language Dictionaries Online'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE LOWER(d.[Page]) LIKE '%www.oxfordlanguagedictionaries.com%'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for OLDO - Oxford Language Dictionaries Online', @@ROWCOUNT


	-- Update Product - Grove Music Online
	UPDATE d
	SET  Supplier = 'Semantico', 
		 Product = 'Grove Music Online',
		 ProductID = '9780199773794'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE [Platform] = 'Grove Music Online'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Platform for Grove Music Online', @@ROWCOUNT

	-- Update Product for ODNB
	UPDATE d
	SET  Supplier = 'Safari', 
		 Product = 'Oxford Dictionary of National Biography',
		 ProductID = '9780198614128'
	--SELECT TOP 100 *
	FROM oupData d
	WHERE [Platform] = 'Oxford Dictionary of National Biography'
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Insert_PageViews', 'Update Product / Supplier for ODNB - Oxford Dictionary of National Biography', @@ROWCOUNT





-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>> oup LOGIC END <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

END



GO



/****** Object:  StoredProcedure [dbo].[oup_Update_Sessionization]   Script Date: 02/22/2009 22:26:28 GMT ******/
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[oup_Update_Sessionization]') AND type in (N'P', N'PC'))
BEGIN
	DROP PROCEDURE [oup_Update_Sessionization]
END

/****** Object:  StoredProcedure [dbo].[oup_Update_Sessionization]    Script Date: 4/10/2014 12:49:31 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROCEDURE:	[oup_Update_Sessionization]
-- CREATED:		05/20/09
-- BY:			Doug Perez
-- DESC:		Updates Sessionization Information in ESEData table for profile  
--				(such as institution, group, consortium and member account numbers
-- NOTES:		
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[oup_Update_Sessionization]
	@Profile					VARCHAR(128),
	@Suspend_Sessionization		BIT = NULL			-- Optional
AS
BEGIN


	-- ************** IMPORTANT NOTE!  PLEAE READ!!!  ****************
	-- Unlike other sessionization, this does NOT populate account information into oupData
	-- Due to the Multi-account nature of the account data.
	-- Instead 

	-- Initialize Variables
	IF @Suspend_Sessionization IS NULL 
		SET @Suspend_Sessionization = 0

	-- Log Start
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'BEGIN', 0


	-- Update ESEData table with sessionization information if enabled
	IF @Suspend_Sessionization = 0
	BEGIN

	

		-- Identify Single Auth Method versus Multi Auth Method Views
		CREATE TABLE #AuthSingleMult
		(
			P_AuthMethID bigint NOT NULL,
			P_AuthMeth varchar(250) NOT NULL,
			SingleIdent varchar(250) NOT NULL,
			IsSingle bit NULL
		)

		CREATE TABLE #ViewList
		(
			ViewID bigint,
			Account varchar(250),
			AccountName varchar(250),
			IP varchar(250),
			HostNum	bigint,
			Source varchar(250)
		)

		CREATE TABLE #IPList
		(
			ViewID bigint,
			IP varchar(250),
			HostNum	bigint,
			Source varchar(250)
		)

		CREATE TABLE #DistinctList
		(
			ViewID bigint,
			Account varchar(250),
			FullAccount varchar(250),
			ConsortiumID int
		)

		CREATE TABLE #DistinctIP
		(
			IP varchar(250),
			HostNum bigint
		)

		INSERT INTO #AuthSingleMult (P_AuthMethID, P_AuthMeth,SingleIdent)
		SELECT P_AuthMethID, P_AuthMeth,
		CASE SUBSTRING(P_AuthMeth, 1, CHARINDEX(',', P_AuthMeth, 0))
			WHEN '' THEN P_AuthMeth
			ELSE SUBSTRING(P_AuthMeth, 1, CHARINDEX(',', P_AuthMeth, 0)-1)
		END as SingleIdent
		FROM [dbo].[oup_P_AuthMethID]
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Identify Auth List', @@ROWCOUNT


		UPDATE #AuthSingleMult
		SET IsSingle=1
		WHERE REPLACE(REPLACE(P_AuthMeth, SingleIdent,''),',','') = ''

		UPDATE #AuthSingleMult
		SET IsSingle=0
		WHERE IsSingle IS NULL

		-- Create table of Single Auth Method Views
		SELECT am.ViewID, P_AuthMeth
		INTO #SingleAuthViews
		FROM oup_P_AuthMeth am
		INNER JOIN #AuthSingleMult tmp ON am.P_AuthMethID = tmp.P_AuthMethID
		INNER JOIN oupData dt ON dt.ViewID = am.ViewID
		WHERE IsSingle = 1
		AND lower(Supplier) = 'highwire'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Single Auth Views', @@ROWCOUNT

		-- Create table of Multi Auth Method Views
		SELECT am.ViewID, P_AuthMeth
		INTO #MultiAuthViews
		FROM oup_P_AuthMeth am
		INNER JOIN #AuthSingleMult tmp ON am.P_AuthMethID = tmp.P_AuthMethID
		INNER JOIN oupData dt ON dt.ViewID = am.ViewID
		WHERE IsSingle = 0
		AND lower(Supplier) = 'highwire'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Multi Auth Views', @@ROWCOUNT


		-- Add Accounts to List for the following conditions

		-- SINGLE AUTH METHOD
		-- AuthnInst
		INSERT INTO #ViewList (ViewID, Account, Source)
		SELECT DISTINCT ai.ViewID, P_AuthnInst, 'AuthnIst_S'
		FROM oup_P_AuthnInst ai
		INNER JOIN oup_P_AuthnInstID auid
			ON ai.P_AuthnInstID = auid.P_AuthnInstID 
		INNER JOIN #SingleAuthViews s
			ON s.ViewID = ai.ViewID
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Populate Single Auth AuthnInst', @@ROWCOUNT

		-- AuthnIPs
		INSERT INTO #IPList (ViewID, IP, Source)
		SELECT DISTINCT ai.ViewID, P_AuthnIPs, 'AuthnIP_S'
		FROM oup_P_AuthnIPs ai
		INNER JOIN oup_P_AuthnIPsID auid
			ON ai.P_AuthnIPsID = auid.P_AuthnIPsID 
		INNER JOIN #SingleAuthViews s
			ON s.ViewID = ai.ViewID
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Populate Single Auth AuthnIPs', @@ROWCOUNT


		-- Multi AUTH METHOD
		-- AuthnInst
		INSERT INTO #ViewList (ViewID, Account, Source)
		SELECT DISTINCT ai.ViewID, P_AuthnInst, 'AuthnIst_M'
		FROM oup_P_AuthnInst ai
		INNER JOIN oup_P_AuthnInstID auid
			ON ai.P_AuthnInstID = auid.P_AuthnInstID 
		INNER JOIN #MultiAuthViews s
			ON s.ViewID = ai.ViewID
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Populate Multi Auth AuthnInst', @@ROWCOUNT

		-- AuthnIPs
		INSERT INTO #IPList (ViewID, IP, Source)
		SELECT DISTINCT ai.ViewID, P_AuthnIPs, 'AuthnIP_M'
		FROM oup_P_AuthnIPs ai
		INNER JOIN oup_P_AuthnIPsID auid
			ON ai.P_AuthnIPsID = auid.P_AuthnIPsID 
		INNER JOIN #MultiAuthViews s
			ON s.ViewID = ai.ViewID
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Populate Multi Auth AuthnIPs', @@ROWCOUNT




		-- IP_Address
		INSERT INTO #IPList (ViewID, IP, Source)
		SELECT d.ViewID, P_IPAddress, 'IPAddress'
		FROM oupData d
		INNER JOIN oup_P_IPAddress ip
			on d.ViewID = ip.ViewID
		INNER JOIN oup_P_IPAddressID ipid
			on ipid.P_IPAddressID = ip.P_IPAddressID
		WHERE d.ViewID NOT IN (
			SELECT d.ViewID FROM oupData d
			INNER JOIN oup_P_AuthMeth am
			ON d.ViewID = am.ViewID
		) 
		AND lower(Supplier) = 'highwire'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Populate Highwire IPAddress', @@ROWCOUNT

		-- ESE HostIP
		INSERT INTO #IPList (ViewID, IP, Source)
		SELECT d.ViewID, Host, 'Host'
		FROM oupData d
		INNER JOIN oup_HostID hid
			ON d.HostID = hid.HostID
		WHERE d.ViewID NOT IN (Select ViewID from #ViewList)
		AND lower(Supplier) = 'highwire'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Populate ESE Host IPAddress', @@ROWCOUNT


		INSERT INTO #DistinctIP (IP)
		SELECT DISTINCT IP FROM #IPList 

		UPDATE #DistinctIP
		SET HostNum = [dbo].[ESE_Get_HostNum](IP)
		WHERE IP IS NOT NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Translate to HostNum', @@ROWCOUNT

		SELECT HostNum, r.site_id, site_name
		INTO #AccountList
		FROM #DistinctIP as il
		INNER JOIN oupRange r
			ON il.HostNum BETWEEN r.low_address AND r.high_address
		INNER JOIN oupSites_1 s
			on r.site_id = s.site_id
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Do IP to Account Mapping', @@ROWCOUNT

		UPDATE #IPList
		SET HostNum = dip.HostNum
		FROM #IPList il INNER JOIN #DistinctIP dip
			on il.IP = dip.IP
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Copy HostNum to IP List', @@ROWCOUNT

		INSERT INTO  #ViewList(ViewID, Account, AccountName, IP, HostNum, Source)
		SELECT ViewID, al.site_id, al.site_name, IP, il.HostNum, Source
		FROM #IPList il
		INNER JOIN #AccountList al
			ON il.HostNum = al.HostNum
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Insert Mapped IP / Mapped Accounts', @@ROWCOUNT



		-- Prep Athen List
		SELECT * 
		INTO #SingleAthensOnly
		FROM #SingleAuthViews 
		WHERE lower(P_AuthMeth) LIKE '%athens%'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Populate Single Auth Athens List', @@ROWCOUNT

		SELECT * 
		INTO #MultiAthensOnly
		FROM #MultiAuthViews 
		WHERE lower(P_AuthMeth) LIKE '%athens%'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Populate Multi Auth Athens List', @@ROWCOUNT


		-- Prep Shibboleth List
		SELECT * 
		INTO #SingleShibbolethOnly
		FROM #SingleAuthViews 
		WHERE lower(P_AuthMeth) LIKE '%shibboleth%'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Populate Single Auth Shibboleth List', @@ROWCOUNT

		SELECT * 
		INTO #MultiShibbolethOnly
		FROM #MultiAuthViews 
		WHERE lower(P_AuthMeth) LIKE '%shibboleth%'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Populate Multi Auth Shibboleth List', @@ROWCOUNT


		-- ***** Add Accounts for Athens and OpenAthens authenticated Users  ************************
		-- Single Auth Meth
		INSERT INTO #ViewList (ViewID, Account, Source)
		SELECT DISTINCT ViewID, site_id, 'Athens_S'
		FROM oupSite_Access_Control sacouter
		INNER JOIN 
		 (
			SELECT DISTINCT va.ViewID, Account, athens_identifier FROM #SingleAthensOnly sa
			INNER JOIN #ViewList va
				ON sa.ViewID = va.ViewID
			INNER JOIN oupSite_Access_Control sac
				ON (sac.site_id COLLATE SQL_Latin1_General_CP1_CI_AS = va.Account)
			) as templist
			ON sacouter.athens_identifier = templist.athens_identifier
		--WHERE sacouter.site_id COLLATE SQL_Latin1_General_CP1_CI_AS IN (
		--	SELECT Account from #ViewList
		--	WHERE ViewID = templist.ViewID)
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Add Single Auth Athens Authenticated Accounts', @@ROWCOUNT


		-- Single Auth Meth
		INSERT INTO #ViewList (ViewID, Account, Source)
		SELECT DISTINCT ViewID, site_id, 'Athens_M'
		FROM oupSite_Access_Control sacouter
		INNER JOIN 
		 (
			SELECT DISTINCT va.ViewID, Account, athens_identifier FROM #MultiAthensOnly sa
			INNER JOIN #ViewList va
				ON sa.ViewID = va.ViewID
			INNER JOIN oupSite_Access_Control sac
				ON (sac.site_id COLLATE SQL_Latin1_General_CP1_CI_AS = va.Account)
			) as templist
			ON sacouter.athens_identifier = templist.athens_identifier
		--WHERE sacouter.site_id COLLATE SQL_Latin1_General_CP1_CI_AS IN (
		--	SELECT Account from #ViewList
		--	WHERE ViewID = templist.ViewID)
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Add Multi Auth Athens Authenticated Accounts', @@ROWCOUNT

		-- ***** Add Accounts for Shibboleth authenticated Users  ************************
		INSERT INTO #ViewList (ViewID, Account, Source)
		SELECT DISTINCT ViewID, InstitutionID, 'Shibboleth_S'
		FROM oupShibboleth_Map smouter
		INNER JOIN 
		 (
			SELECT DISTINCT va.ViewID, Account, HighWireID FROM #SingleShibbolethOnly so
			INNER JOIN #ViewList va
				ON so.ViewID = va.ViewID
			INNER JOIN oupShibboleth_Map sm
				ON (sm.InstitutionID COLLATE SQL_Latin1_General_CP1_CI_AS = va.Account)
			) as templist
			ON smouter.HighWireID = templist.HighWireID
		--WHERE smouter.InstitutionID COLLATE SQL_Latin1_General_CP1_CI_AS IN (
		--	SELECT Account from #ViewList
		--	WHERE ViewID = templist.ViewID)	
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Add Single Auth Shibboleth Authenticated Accounts', @@ROWCOUNT

		INSERT INTO #ViewList (ViewID, Account, Source)
		SELECT DISTINCT ViewID, InstitutionID, 'Shibboleth_M'
		FROM oupShibboleth_Map smouter
		INNER JOIN 
		 (
			SELECT DISTINCT va.ViewID, Account, HighWireID FROM #MultiShibbolethOnly so
			INNER JOIN #ViewList va
				ON so.ViewID = va.ViewID
			INNER JOIN oupShibboleth_Map sm
				ON (sm.InstitutionID COLLATE SQL_Latin1_General_CP1_CI_AS = va.Account)
			) as templist
			ON smouter.HighWireID = templist.HighWireID
		--WHERE smouter.InstitutionID COLLATE SQL_Latin1_General_CP1_CI_AS IN (
		--	SELECT Account from #ViewList
		--	WHERE ViewID = templist.ViewID)	
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Add Multi Auth Shibboleth Authenticated Accounts', @@ROWCOUNT

		
		UPDATE #ViewList
		SET AccountName = site_name
		FROM #ViewList vl INNER JOIN oupSites s
			ON vl.Account COLLATE SQL_Latin1_General_CP1_CI_AS = s.site_id
		WHERE vl.AccountName IS NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Update Account Names', @@ROWCOUNT
		
		-- Define a distinct set of ViewID / Account combinations
		
		CREATE INDEX DL_VW_Acct
		ON #ViewList(ViewID, Account)
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Create View List Index', @@ROWCOUNT

		INSERT INTO #DistinctList (ViewID, Account, FullAccount)
		SELECT DISTINCT ViewID, Account, Account + ' - ' + AccountName
		FROM #ViewList
		WHERE Account IS NOT NULL
		ORDER BY ViewID
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Dedupe List', @@ROWCOUNT

		CREATE INDEX DL_acc
		ON #DistinctList (Account)
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Create Account Index', @@ROWCOUNT

		UPDATE #DistinctList
		SET FullAccount = Account + ' - ' + site_name COLLATE SQL_Latin1_General_CP1_CI_AS
		FROM #DistinctList dl
		INNER JOIN oupSites_1  s
			on dl.Account = 
				CASE 
					WHEN len(site_id) <= 8 THEN Replicate ('0', 8-LEN(site_id)) + site_id
					ELSE site_id
				END COLLATE SQL_Latin1_General_CP1_CI_AS
		WHERE FullAccount IS NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Add FullAcount name (Base Case)', @@ROWCOUNT

		UPDATE #DistinctList
		SET FullAccount = Account + ' - ' + site_name COLLATE SQL_Latin1_General_CP1_CI_AS 
				FROM #DistinctList dl
		INNER JOIN oupSites_1  s
			on dl.Account = s.site_id COLLATE SQL_Latin1_General_CP1_CI_AS
		WHERE len(site_id) < 8 AND FullAccount IS NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Add FullAcount name (Special Case)', @@ROWCOUNT

		-- Update any UnMapped Sites
		UPDATE #DistinctList
		SET FullAccount = Account + ' (Unmapped)'
		WHERE FullAccount IS NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Add FullAcount name (Unmapped Case)', @@ROWCOUNT


		-- ************************************ Begin Consortia Assignment



		UPDATE #DistinctList
		SET ConsortiumID = c.consortium_id
		FROM #DistinctList v
			INNER JOIN oupConsortia_Members_1 cm ON cm.InstitutionID = v.Account COLLATE Latin1_General_BIN
			INNER JOIN oupConsortia c ON c.consortium_id = cm.ConsortiumID
			INNER JOIN oup_Views vw ON vw.ViewID = v.ViewID
		WHERE vw.ViewDateTime BETWEEN cm.StartDate and ISNULL(cm.EndDate, '12/31/9999')
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Log Consortia Accounts', @@ROWCOUNT

		SELECT DISTINCT ViewID, l.ConsortiumID, ConsortiumName, CONVERT(varchar(250),l.ConsortiumID) + ' - ' + ConsortiumName as ConFullName
		INTO #DistinctConList
		FROM #DistinctList l
		INNER JOIN oupConsortia_1 c
			ON l.ConsortiumID = c.ConsortiumID
		WHERE l.ConsortiumID IS NOT NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Dedupe Consortia', @@ROWCOUNT


		-- ****************** Safari Account Assignment ***********************
		INSERT INTO #DistinctList (ViewID, Account, FullAccount)
		SELECT DISTINCT dt.ViewID, site_id AS 'Account', site_id + ' - ' + site_name AS 'FullAccount'
		FROM oupData dt
			INNER JOIN oup_P_AcctID act on dt.ViewID = act.ViewID
			INNER JOIN oup_P_AcctIDID actid on act.P_AcctIDID = actid.P_AcctIDID
			INNER JOIN oupSites_2 st on st.site_id = actid.P_AcctID
-- SUBSCRIPTION FEED NEEDS TO BE ADDRESSED
--			INNER JOIN oupSite_Product sp on sp.site_id = st.site_id
--				AND sp.product_id = dt.ProductID
		ORDER BY dt.ViewID
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Update Account for Safari', @@ROWCOUNT


-- CODE BELOW IN NOT WORKING DUE TO JOINS BETWEEN THE Sites, Consortia Members and Consortia feeds
		INSERT INTO #DistinctConList (ViewID, ConsortiumID, ConsortiumName, ConFullName)
		SELECT DISTINCT dt.ViewID, ct.ConsortiumID, ct.ConsortiumName, CONVERT(varchar(250),ct.ConsortiumID) + ' - ' + ct.ConsortiumName as ConFullName
		FROM oupData dt
			INNER JOIN oup_P_AcctID act on dt.ViewID = act.ViewID
			INNER JOIN oup_P_AcctIDID actid on act.P_AcctIDID = actid.P_AcctIDID
			INNER JOIN oupSites_2 st on st.site_id = actid.P_AcctID
			INNER JOIN oupConsortia_Members_2 cm on cm.InstitutionID = st.site_id
			INNER JOIN oupConsortia_2 ct on ct.ConsortiumID = cm.ConsortiumID
-- SUBSCRIPTION FEED NEEDS TO BE ADDRESSED
--			INNER JOIN oupSite_Product sp on sp.site_id = st.site_id
--				AND sp.product_id = dt.ProductID
		ORDER BY dt.ViewID
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Update Consortia for Safari', @@ROWCOUNT



		-- ****************** Parameter Insert  *******************************

		-- Insert distinct parm values into key table (be sure this table is set to auto-increment!!)
		INSERT INTO oup_P_AccountID (P_Account)
			SELECT DISTINCT FullAccount
			FROM #DistinctList
			WHERE FullAccount COLLATE Latin1_General_BIN NOT IN (SELECT P_Account FROM oup_P_AccountID)
			AND FullAccount IS NOT NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Insert New Accounts into Parameter', @@ROWCOUNT


		-- Delete existing records based on viewid range and insert new records
		 DELETE FROM oup_P_Account WHERE ViewID IN (SELECT ViewID FROM #DistinctList);

		CREATE INDEX IDXFullAccount
		ON #DistinctList(FullAccount)
		 
		 -- Insert new Accounts for current views
		 INSERT INTO oup_P_Account (ViewID, P_AccountID, ArrayPos)
		 SELECT ViewID, P_AccountID, ROW_NUMBER() OVER (PARTITION BY ViewID ORDER BY Account)
		 FROM #DistinctList va
		 INNER JOIN oup_P_AccountID acid
			ON va.FullAccount COLLATE Latin1_General_BIN = acid.P_Account
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Insert New Views into Parameter', @@ROWCOUNT


		 --Consortia Parms
		INSERT INTO oup_P_ConsortiumID (P_Consortium)
			SELECT DISTINCT ConFullName
			FROM #DistinctConList
			WHERE ConFullName COLLATE Latin1_General_BIN NOT IN (SELECT P_Consortium FROM oup_P_ConsortiumID)
			AND ConFullName IS NOT NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Insert New Consortia into Parameter', @@ROWCOUNT


			-- Delete existing records based on viewid range and insert new records
		 DELETE FROM oup_P_Consortium WHERE ViewID IN (SELECT ViewID FROM #DistinctConList);

		CREATE INDEX IDXConFullName
		ON #DistinctConList(ConFullName)
		  
		  --Insert new Accounts for current views
		 INSERT INTO oup_P_Consortium (ViewID, P_ConsortiumID, ArrayPos)
		 SELECT ViewID, P_ConsortiumID, ROW_NUMBER() OVER (PARTITION BY ViewID ORDER BY ConsortiumName)
		 FROM #DistinctConList va
		 INNER JOIN oup_P_ConsortiumID acid
			ON va.ConFullName COLLATE Latin1_General_BIN = acid.P_Consortium
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Insert New Views into Parameter', @@ROWCOUNT


		--Update NetInsight Parameters from sams_subscriptions Feed (Institutions) (Must be executed following sessionization!)
		UPDATE d
		SET	 d.SubStatus = ss.SubscriptionStatus
			,d.SubType = ss.SubscriptionType
			,d.AcctType = ss.AccountType
		FROM oupData d
		JOIN oup_P_Account a
			ON d.ViewID = a.ViewID
		JOIN oup_P_AccountID aid
			ON a.P_AccountID = aid.P_AccountID
		JOIN oupSams_Subscriptions ss
			ON ss.AccountID = CASE WHEN PATINDEX('% - %', aid.P_Account) <> 0
																THEN SUBSTRING(aid.P_Account, 1, PATINDEX('% - %', aid.P_Account) -1)
															 WHEN PATINDEX('% -%', aid.P_Account) <> 0
																THEN SUBSTRING(aid.P_Account, 1, PATINDEX('% -%', aid.P_Account) -1)
															 ELSE aid.P_Account
															 END
		WHERE d.PageCode IS NOT NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Update NetInsight Parameters from Sams_Subcriptions Feed (Institutions)', @@ROWCOUNT

		--Update NetInsight Parameters from sams_subscriptions Feed (Consortia) (Must be executed following sessionization!)
		UPDATE d
		SET	 d.SubStatus = ss.SubscriptionStatus
			,d.SubType = ss.SubscriptionType
			,d.AcctType = ss.AccountType
		FROM oupData d
		JOIN oup_P_Consortium c
			ON d.ViewID = c.ViewID
		JOIN oup_P_ConsortiumID cid
			ON c.P_ConsortiumID = cid.P_ConsortiumID
		JOIN oupSams_Subscriptions ss
			ON ss.AccountID = CASE WHEN PATINDEX('% - %', cid.P_Consortium) <> 0
																THEN SUBSTRING(cid.P_Consortium, 1, PATINDEX('% - %', cid.P_Consortium) -1)
															 WHEN PATINDEX('% -%', cid.P_Consortium) <> 0
																THEN SUBSTRING(cid.P_Consortium, 1, PATINDEX('% -%', cid.P_Consortium) -1)
															 ELSE cid.P_Consortium
															 END
		WHERE d.PageCode IS NOT NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Update NetInsight Parameters from Sams_Subcriptions Feed (Consortia)', @@ROWCOUNT

		--Update sams_consortia parameter


		SELECT DISTINCT 
				 d.ViewID
				,c2.AccountID
				,c2.Organisation
				,CAST(c2.AccountID AS VARCHAR) + ' - ' + c2.Organisation AS ConFullName
			INTO #DistinctConsortiumList
			FROM #views d
			JOIN oup_P_AcctID act
				ON d.ViewID = act.ViewID
			JOIN oup_P_AcctIDID actid
				ON act.P_AcctIDID = actid.P_AcctIDID
			JOIN (SELECT DISTINCT AccountID FROM oupSams_Subscriptions) s
				ON actid.P_AcctID = s.AccountID
			JOIN oupSams_ConsortiaTemp c
				ON s.AccountID = c.AccountID
			JOIN oupSams_ConsortiaTemp c2
				ON c.GroupSubscriptionID = c2.SubscriptionID
				AND c2.AccountType = 'Consortium'
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Repopulate #DistinctConList (Consortia)', @@ROWCOUNT


		INSERT INTO [dbo].[oup_P_samscnsortID] (P_samscnsort)
			SELECT DISTINCT ConFullName
			FROM #DistinctConsortiumList
			WHERE ConFullName COLLATE Latin1_General_BIN NOT IN (SELECT P_samscnsort FROM oup_P_samscnsortID)
			AND ConFullName IS NOT NULL
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Insert Values in oup_P_samscnsortID (Consortia)', @@ROWCOUNT

		DELETE FROM oup_P_samscnsort WHERE ViewID IN (SELECT ViewID FROM #DistinctConsortiumList)

		CREATE INDEX IDXConFullName
		ON #DistinctConsortiumList(ConFullName)
		  
		  --Insert new Accounts for current views
		 INSERT INTO oup_P_samscnsort (ViewID, P_samscnsortID, ArrayPos)
		 SELECT ViewID, P_samscnsortID, ROW_NUMBER() OVER (PARTITION BY ViewID ORDER BY Organisation)
		 FROM #DistinctConsortiumList va
		 INNER JOIN oup_P_samscnsortID acid
			ON va.ConFullName COLLATE Latin1_General_BIN = acid.P_samscnsort
		EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'Insert Values in oup_P_samscnsort (Consortia)', @@ROWCOUNT


		DROP TABLE #DistinctConsortiumList




		DROP TABLE #AuthSingleMult
		DROP TABLE #SingleAuthViews
		DROP TABLE #MultiAuthViews
		DROP TABLE #ViewList
		DROP TABLE #SingleAthensOnly 
		DROP TABLE #SingleShibbolethOnly
		DROP TABLE #DistinctList
		DROP TABLE #MultiAthensOnly
		DROP TABLE #MultiShibbolethOnly
		DROP TABLE #DistinctConList
		DROP TABLE #IPList
		DROP TABLE #DistinctIP
		DROP TABLE #AccountList
	END

	-- Log End
	EXEC [ESE_Insert_LogEvent] @Profile, 'oup_Update_Sessionization', 'END', 0

END


GO




--exec ESE_DataAnalyzer 'oup', '1/01/2014', '2014-02-27 23:59:59.000'

--select MAX(ViewDateTime) from oup_Views




