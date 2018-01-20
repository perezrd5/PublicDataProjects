IF EXISTS (SELECT * FROM sys.objects WHERE name = 'ReportEBAAAnnual_Populate')
	DROP PROCEDURE dbo.ReportEBAAAnnual_Populate

GO


/****** Object:  StoredProcedure [dbo].[ReportEBAAAnnual_Populate]    Script Date: 3/8/2014 9:13:59 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


--*********************************************************************************
--Author : Doug Perez
--Created Date : 03/08/2014
--**********************************************************************************

CREATE PROCEDURE [dbo].[ReportEBAAAnnual_Populate]
	(
	 @OrganizationID UNIQUEIDENTIFIER
	,@deathStartDate DATETIME = NULL
	,@deathEndDate DATETIME = NULL
	)
AS
/*
Procedure Name:		dbo.ReportEBAAAnnual_Populate
Author:				Doug Perez
Execution Example:	EXEC dbo.ReportEBAAAnnual_Populate
						 @OrganizationID = '7AEBC1F3-822D-4CE7-86C1-354EC01C629B'
						,@deathStartDate = '20120101'
						,@deathEndDate = '20130101'
Parameter Definitions:		None at this time.
Purpose:			Populates warehouse table for EBAA Annual Report
Change History:		Date		Author			Comment
					3/8/2014	DP				Original Code
*/

SET NOCOUNT ON;
SET ANSI_WARNINGS OFF;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @reportYear INT
DECLARE @timeZone UNIQUEIDENTIFIER

SELECT @timeZone = TimeZoneID
FROM dbo.Organization
WHERE ID = @OrganizationID

IF @timeZone IS NULL
	SET @timeZone = 'F63B90D8-BD45-46E7-97C6-735F805019D9'

SET @reportYear = DATEPART(yyyy, @deathStartDate)

IF DATEPART(yyyy, dbo.ToLocalDateTime(@deathStartDate, @timeZone)) <> DATEPART(yyyy, dbo.ToLocalDateTime(@deathEndDate, @timeZone))
	PRINT 'This procedure may only be run for a single calendar year'

ELSE IF @deathStartDate IS NOT NULL
BEGIN

	DECLARE @usageType UNIQUEIDENTIFIER = dbo.GetEnumerationID(@organizationID, 'EyeTissueUsageType')
	DECLARE @usageDetailType UNIQUEIDENTIFIER = dbo.GetEnumerationID(@organizationID, 'EyeTissueUsageDetailType')
	DECLARE @dxType UNIQUEIDENTIFIER = dbo.GetEnumerationID(@organizationID, 'PreOpDiagnosisType')

	DELETE dbo.EBAAReportWarehouse
	WHERE ReportYear = @reportYear

	CREATE TABLE #referrals
		(
		 ID INT IDENTITY(1,1)
		,ReferralID UNIQUEIDENTIFIER
		,MonthText VARCHAR(100)
		,PatientID UNIQUEIDENTIFIER
		,CaseFileType VARCHAR(15)
		)

	SELECT ID 
	INTO #ocularTypes
	FROM EyeRecovery.EyeTissueDescriptor 
	WHERE  EyeTissueDescriptorTypeId IN (SELECT ID FROM  EyeRecovery.EyeTissueDescriptorType WHERE Name = 'ConsentTissueType' ) 
	AND Name IN ('Eyes','Whole Eye', 'Corneas Only','Cornea','Corneas')

	SELECT ID 
	INTO #tissueTypes
	FROM dbo.TissueType 
	WHERE Name IN ('Eye Tissue','Whole Eyes','Corneas','Corneas Only','Eyes','Corneas Only (in-situ)')

	INSERT #referrals (ReferralID, MonthText, PatientID,CaseFileType)
	SELECT DISTINCT r.ID, DATENAME(MONTH, dbo.ToLocalDateTime(dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn), @timeZone)) MonthText, r.PatientID,r.CaseFileType
	FROM dbo.Referral r WITH(NOLOCK)
	JOIN dbo.DonorReferral dr WITH(NOLOCK)
		ON r.ID = dr.ReferralID
	LEFT JOIN dbo.OrganizationInGroup oig WITH(NOLOCK)
		ON r.ReferringOrganizationId = oig.OrganizationID
	WHERE (r.OrganizationID = @OrganizationID OR r.TakenByOrganizationID = @OrganizationID)
	AND dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn) BETWEEN @deathStartDate AND @deathEndDate

	CREATE CLUSTERED INDEX #ix_Referrals_ID ON #referrals(ID)
	CREATE NONCLUSTERED INDEX #ix_Referrals_ReferralID ON #referrals(ReferralID)


	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'TotalDeathReferrals' Label, '01.A' Sort, @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,COUNT(DISTINCT r.ID) ReferralCount			
		FROM #referrals r
		WHERE r.CaseFileType='Referral'
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p
	 
	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DeathReferralsEligibleForTransplant', '01.B', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 MonthText
			,SUM(CASE WHEN ISNULL(odo.PatientID, tdo.PatientID) IS NOT NULL THEN 1 END) ReferralCount
		FROM #referrals r
		LEFT JOIN (dbo.OcularDonorOutcome odo
				   JOIN #ocularTypes o
						ON odo.TissueTypeID = o.ID
						AND odo.Suitable = 1
						AND odo.SuitabilityType = 'TX')
			ON r.PatientID = odo.PatientID
		LEFT JOIN (dbo.TissueDonorOutcome tdo
				   JOIN #tissueTypes t
						ON tdo.TissueTypeID = t.ID
						AND tdo.Suitable = 1 AND tdo.SuitabilityType = 'TX')
			ON r.PatientID = tdo.PatientID
		GROUP BY MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 
	 

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DonorsRecoveredNotRegistered', '02.A.01', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,COUNT(DISTINCT CASE WHEN etr.CaseFileId IS NOT NULL AND ev.Value IS NOT NULL THEN r.ID END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		JOIN dbo.DonorReferral dr WITH(NOLOCK)
			ON r.ReferralID = dr.ReferralID
		
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.Oculus in ('OD','OS')
		LEFT JOIN dbo.EnumerationValue ev WITH(NOLOCK)
			ON ev.EnumerationTypeID = dbo.GetEnumerationID(@organizationID, 'DonorDesignationStatusType')
			AND dr.DonorDesignationStatus = ev.Value
			AND ev.[Description] IN ('Not Registered', 'Not Available','Not Designated')
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 
	 
	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DonorsRecoveredRegistered', '02.A.02',@reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,COUNT(DISTINCT CASE WHEN etr.CaseFileId IS NOT NULL AND ev.Value IS NOT NULL THEN r.ID END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		JOIN dbo.DonorReferral dr WITH(NOLOCK)
			ON r.ReferralID = dr.ReferralID

		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.Oculus in ('OD','OS')
		LEFT JOIN dbo.EnumerationValue ev WITH(NOLOCK)
			ON ev.EnumerationTypeID = dbo.GetEnumerationID(@organizationID, 'DonorDesignationStatusType')
			AND dr.DonorDesignationStatus = ev.Value
			AND ev.[Description] IN ('Registered', 'Registered Yes','Designated Yes DVS','Designated Yes Online Registry','DNA','MVD','Both','Registered No','Out of State')
		GROUP BY MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 
	 
	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'EyesCorneasRecoveredSurgical', '02.B',@reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,COUNT(DISTINCT CASE WHEN etr.CaseFileID IS NOT NULL THEN etr.ID END) ReferralCount
		FROM #referrals r WITH(NOLOCK) 
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryIntent = 1 --1 = Transplant; 2 = Research; 3 = Training
			AND etr.ParentID IS NULL --No child records!
			AND ((etr.RecoveryTissueType = 'CN' AND etr.RecoveryTissueSubType = 'WCN')
				  OR etr.RecoveryTissueType = 'WE')
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 
	 
	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'EyesCorneasRecoveredOther', '02.C', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,COUNT(DISTINCT CASE WHEN etr.CaseFileID IS NOT NULL THEN etr.ID END) ReferralCount
		FROM #referrals r WITH(NOLOCK)		
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryIntent IN (2,3) --1 = Transplant; 2 = Research; 3 = Training
			AND etr.ParentID IS NULL --No child records!
			AND ((etr.RecoveryTissueType = 'CN' AND etr.RecoveryTissueSubType = 'WCN')
				  OR etr.RecoveryTissueType = 'WE')
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT *
	FROM (
		SELECT
			 base.Label
			,base.sort
			,@reportYear ReportYear
			,NULL as YearCalculation
			,r.MonthText
			,COUNT(DISTINCT CASE WHEN etr.CaseFileId IS NOT NULL AND ev.Value IS NOT NULL THEN r.ID END) ReferralCount
		FROM 
		(SELECT 'AgeUnder1Year' Label, '03.A.01' Sort
			UNION ALL
			SELECT 'Age01To10', '03.A.02'
			UNION ALL
			SELECT 'Age11To20', '03.A.03'
			UNION ALL
			SELECT 'Age21To30', '03.A.04'
			UNION ALL
			SELECT 'Age31To40', '03.A.05'
			UNION ALL
			SELECT 'Age41To50', '03.A.06'
			UNION ALL
			SELECT 'Age51To60', '03.A.07'
			UNION ALL
			SELECT 'Age61To70', '03.A.08'
			UNION ALL
			SELECT 'Age71To80', '03.A.09'
			UNION ALL
			SELECT 'AgeOver80', '03.A.10') base
		LEFT JOIN (#referrals r WITH(NOLOCK)
					LEFT JOIN dbo.Patient p WITH(NOLOCK)
						ON r.PatientID = p.ID
					LEFT JOIN dbo.DonorReferral dr WITH(NOLOCK)
						ON r.ReferralID = dr.ReferralID)
			ON base.sort = CASE WHEN ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) >= 0 AND ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) < 1 THEN '03.A.01'
							 WHEN ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) >= 1 AND ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) < 11 THEN '03.A.02'
							 WHEN ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) >= 11 AND ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) < 21 THEN '03.A.03'
							 WHEN ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) >= 21 AND ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) < 31 THEN '03.A.04'
							 WHEN ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) >= 31 AND ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) < 41 THEN '03.A.05'
							 WHEN ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) >= 41 AND ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) < 51 THEN '03.A.06'
							 WHEN ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) >= 51 AND ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) < 61 THEN '03.A.07'
							 WHEN ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) >= 61 AND ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) < 71 THEN '03.A.08'
							 WHEN ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) >= 71 AND ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) < 81 THEN '03.A.09'
							 WHEN ISNULL((DATEDIFF(MONTH, p.BirthDate, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) - CASE WHEN DATEPART(DAY, p.BirthDate) > DATEPART(DAY, dbo.GetDeathDateTime(dr.CrossClampedOn, dr.AsystoleDeathOn, dr.LTKAOn)) THEN 1 ELSE 0 END)/12, -1) >= 81 THEN '03.A.10'
							 END

		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID
			AND etr.Oculus in ('OD','OS')		
		LEFT JOIN dbo.EnumerationValue ev WITH(NOLOCK)
			ON ev.EnumerationTypeID = dbo.GetEnumerationID(@organizationID, 'DonorDesignationStatusType')
			AND dr.DonorDesignationStatus = ev.Value AND dr.DonorDesignationStatus IS NOT NULL
			
		GROUP BY base.Label
			,base.sort
			,r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT *
	FROM (
		SELECT
			 base.Label
			,base.Sort
			,@reportYear ReportYear
			,NULL as YearCalculation
			,r.MonthText
			,COUNT(DISTINCT CASE WHEN etr.CaseFileId IS NOT NULL AND ev.Value IS NOT NULL THEN r.ID END) ReferralCount
		FROM (SELECT 'GenderMale' Label, '03.B.01' Sort
				UNION ALL
				SELECT 'GenderFemale', '03.B.02') base
		LEFT JOIN (#referrals r WITH(NOLOCK)
					JOIN dbo.Patient p WITH(NOLOCK)
						ON r.PatientID = p.ID)
			ON base.Sort = CASE p.Sex WHEN 'M' THEN '03.B.01'
									   WHEN 'F' THEN '03.B.02'
									   END
		LEFT JOIN dbo.DonorReferral dr WITH(NOLOCK)
			ON r.ReferralID = dr.ReferralID AND r.CaseFileType='Referral'
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID
			AND etr.Oculus in ('OD','OS')		
		LEFT JOIN dbo.EnumerationValue ev WITH(NOLOCK)
			ON ev.EnumerationTypeID = dbo.GetEnumerationID(@organizationID, 'DonorDesignationStatusType')
			AND dr.DonorDesignationStatus = ev.Value AND dr.DonorDesignationStatus IS NOT NULL
			
		GROUP BY base.Label
			,base.sort
			,r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 
	
	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT *
	FROM (
		SELECT
			 base.Label
			,base.Sort
			,@reportYear ReportYear
			,NULL as YearCalculation
			,r.MonthText
			,COUNT(DISTINCT CASE WHEN etr.CaseFileId IS NOT NULL AND ev.Value IS NOT NULL THEN r.ID END) ReferralCount
		FROM (SELECT 'EBAACauseOfDeath-HeartDisease' Label, '03.C.01' Sort
				UNION ALL
				SELECT 'EBAACauseOfDeath-Cancer' Label, '03.C.02' Sort
				UNION ALL
				SELECT 'EBAACauseOfDeath-CerebralVascularAccident' Label, '03.C.03' Sort
				UNION ALL
				SELECT 'EBAACauseOfDeath-RespiratoryDisease' Label, '03.C.04' Sort
				UNION ALL
				SELECT 'EBAACauseOfDeath-Trauma' Label, '03.C.05' Sort
				UNION ALL
				SELECT 'EBAACauseOfDeath-Other' Label, '03.C.06' Sort) base
		LEFT JOIN (#referrals r WITH(NOLOCK)
					LEFT JOIN dbo.Patient p WITH(NOLOCK)
						ON r.PatientID = p.ID
					LEFT JOIN dbo.DonorReferral dr WITH(NOLOCK)
						ON r.ReferralID = dr.ReferralID
					LEFT JOIN dbo.EnumerationValue e
						ON e.EnumerationTypeID = dbo.GetEnumerationID(@organizationID, 'EyeCauseOfDeathType')
						AND dr.EyeCauseOfDeath = e.Value)			
			ON base.Sort = CASE e.Description WHEN 'Heart Disease' THEN '03.C.01'
									   WHEN 'Cancer'THEN '03.C.02'
									   WHEN 'Cerebral Vascular Accident' THEN '03.C.03'
									   WHEN 'Respiratory Disease' THEN '03.C.04'
									   WHEN 'Trauma' THEN '03.C.05'
									   WHEN 'Other' THEN '03.C.06'
									   WHEN 'Other Diseases' THEN '03.C.06'
									   END
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.Oculus in ('OD','OS')
		
		LEFT JOIN dbo.EnumerationValue ev WITH(NOLOCK)
			ON ev.EnumerationTypeID = dbo.GetEnumerationID(@organizationID, 'DonorDesignationStatusType')
			AND dr.DonorDesignationStatus = ev.Value AND dr.DonorDesignationStatus IS NOT NULL

		GROUP BY base.Label
			,base.Sort
			,r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 
	
	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	--Below is Section IV A-D.  Code was based on the existing Cornea Discard Report, and easier to query all at once using an UNPIVOT and PIVOT.
	SELECT 
		 Label + [Type] Label
		,Sort = CASE [Type] WHEN 'HIVAntibody' THEN '04.A.01.A.01'
							WHEN 'HIVNucleicAcidTest' THEN '04.A.01.A.02'
							WHEN 'HepatitisBSurfaceAntigen' THEN '04.A.01.A.03'
							WHEN 'HepatitisBCoreAntibody' THEN '04.A.01.A.04'
							WHEN 'HepatitisCAntibody' THEN '04.A.01.A.05'
							WHEN 'HepatitisCNucleicAcidTest' THEN '04.A.01.A.06'
							WHEN 'Syphilis' THEN '04.A.01.A.07'
							WHEN 'HTLVAntibody' THEN '04.A.01.A.08'
							WHEN 'NSFTSerologyOther' THEN '04.A.01.A.09'
							WHEN 'NsftSerologyOtherCommunicable' THEN '04.A.01.B'
							WHEN 'DementiaNeurologicalIssues' THEN '04.A.01.C.01'
							WHEN 'SepsisPositiveBloodCultures' THEN '04.A.01.C.02'
							WHEN 'SepsisOther' THEN '04.A.01.C.03'
							WHEN 'PlasmaDilution' THEN '04.A.01.C.04'
							WHEN 'UnknownCauseOfDeath' THEN '04.A.01.C.05'
							WHEN 'NsftMedicalRecordOther' THEN '04.A.01.C.06'
							WHEN 'Travel' THEN '04.A.01.D.01'
							WHEN 'MedSocDementiaNeurologicalIssues' THEN '04.A.01.D.02'
							WHEN 'NsftMedSocInterviewOther' THEN '04.A.01.D.03'
							WHEN 'NsftBodyExam' THEN '04.A.01.E'
							WHEN 'NsftEpithelium' THEN '04.A.02.A'
							WHEN 'PriorRefractiveSurgery' THEN '04.A.02.B.01'
							WHEN 'Scar' THEN '04.A.02.B.02'
							WHEN 'Infiltrate' THEN '04.A.02.B.03'
							WHEN 'ForeignBody' THEN '04.A.02.B.04'
							WHEN 'NsftStromaOther' THEN '04.A.02.B.05'
							WHEN 'NsftDescemetsMembrane' THEN '04.A.02.C'
							WHEN 'NsftEndothelium' THEN '04.A.02.D'
							WHEN 'Storage' THEN '04.A.03.A'
							WHEN 'Labeling' THEN '04.A.03.B'
							WHEN 'Processing' THEN '04.A.03.C'
							WHEN 'SupplyOrReagent' THEN '04.A.03.D'
							WHEN 'EnvironmentalControl' THEN '04.A.03.E'
							WHEN 'NsftQualityOther' THEN '04.A.04'
							WHEN 'TotalDiscardedTissuesNotReleased' THEN '04.B'
							WHEN 'TransportationIssue' THEN '04.C.01'
							WHEN 'SurgeonIssue' THEN '04.C.02'
							WHEN 'RecipientIssue' THEN '04.C.03'
							WHEN 'ReturnedUnableToPlaceAgain' THEN '04.C.04'
							WHEN 'DonorInformationNotAvailable' THEN '04.C.05'
							WHEN 'Expired' THEN '04.C.06'
							WHEN 'TissueDamagedDuringProcessing' THEN '04.C.07'
							WHEN 'NsftPostReleaseOther' THEN '04.C.08'
							WHEN 'TotalDiscardedTissues' THEN '04.D'
							END
		,@reportYear
		,NULL as YearCalculation
		,[January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December]
	FROM
			(SELECT *
			 FROM (
				  
				SELECT  'Section IV-' Label,
						r.MonthText,
					-- 'Donor Eligibility',
					--
					SUM (Case WHEN ((eyeTissueRecovered.NsftSerology & 1) = 1)
							THEN 1
							ELSE 0
						END) as 'HIVAntibody',
					SUM (Case WHEN ((eyeTissueRecovered.NsftSerology & 2) = 2)
							THEN 1
							ELSE 0
						END) as 'HIVNucleicAcidTest',
						SUM (Case WHEN ((eyeTissueRecovered.NsftSerology & 4) = 4)
							THEN 1
							ELSE 0
						END) as 'HepatitisBSurfaceAntigen',
						SUM (Case WHEN ((eyeTissueRecovered.NsftSerology & 8) = 8)
							THEN 1
							ELSE 0
						END) as 'HepatitisBCoreAntibody',
						SUM (Case WHEN ((eyeTissueRecovered.NsftSerology & 16) = 16)
							THEN 1
							ELSE 0
						END) as 'HepatitisCAntibody',
						SUM (Case WHEN ((eyeTissueRecovered.NsftSerology & 32) = 32)
							THEN 1
							ELSE 0
						END) as 'HepatitisCNucleicAcidTest',
						SUM (Case WHEN ((eyeTissueRecovered.NsftSerology & 64) = 64)
							THEN 1
							ELSE 0
						END) as 'Syphilis',
						SUM (Case WHEN ((eyeTissueRecovered.NsftSerology & 128) = 128)
							THEN 1
							ELSE 0
						END) as 'HTLVAntibody',
				
					 SUM (Case WHEN (eyeTissueRecovered.NsftSerologyOther = 1)
							THEN 1
							ELSE 0
						END) as 'NsftSerologyOther',
					 SUM (Case WHEN (eyeTissueRecovered.NsftSerologyOtherCommunicable = 1)
							THEN 1
							ELSE 0
						END) as 'NsftSerologyOtherCommunicable',
						--
						-- 'Medical Record or Autopsy',
						--
						 SUM (Case WHEN (eyeTissueRecovered.NsftMedicalRecord & 1 = 1)
							THEN 1
							ELSE 0
						END) as 'DementiaNeurologicalIssues',   
						 SUM (Case WHEN (eyeTissueRecovered.NsftMedicalRecord & 2 = 2)
							THEN 1
							ELSE 0
						END) as 'SepsisPositiveBloodCultures',   
						 SUM (Case WHEN (eyeTissueRecovered.NsftMedicalRecord & 4 = 4)
							THEN 1
							ELSE 0
						END) as 'SepsisOther',   
						 SUM (Case WHEN (eyeTissueRecovered.NsftMedicalRecord & 8 = 8)
							THEN 1
							ELSE 0
						END) as 'PlasmaDilution',   
						SUM (Case WHEN (eyeTissueRecovered.NsftMedicalRecord & 16 = 16)
							THEN 1
							ELSE 0
						END) as 'UnknownCauseOfDeath',
						SUM (Case WHEN (eyeTissueRecovered.NsftMedicalRecordOther = 1)
							THEN 1
							ELSE 0
						END) as 'NsftMedicalRecordOther',
						--
						-- 'Medical/Social History Interview',
						--
						SUM (Case WHEN (eyeTissueRecovered.NsftMedSocInterview & 1 = 1)
							THEN 1
							ELSE 0
						END) as 'Travel',
						SUM (Case WHEN (eyeTissueRecovered.NsftMedSocInterview & 2 = 2)
							THEN 1
							ELSE 0
						END) as 'MedSocDementiaNeurologicalIssues',
						SUM (Case WHEN (eyeTissueRecovered.NsftMedSocInterviewOther = 1)
							THEN 1
							ELSE 0
						END) as 'NsftMedSocInterviewOther',
						SUM (Case WHEN (eyeTissueRecovered.NsftBodyExam = 1)
							THEN 1
							ELSE 0
						END) as 'NsftBodyExam',
						--
						-- 'Tissue Suitability',
						--
						SUM (Case WHEN (eyeTissueRecovered.NsftEpithelium = 1)
							THEN 1
							ELSE 0
						END) as 'NsftEpithelium',
						--
						--null as 'Stroma',
						--
						SUM (Case WHEN (eyeTissueRecovered.NsftStroma & 1 = 1)
							THEN 1
							ELSE 0
						END) as 'PriorRefractiveSurgery',
						SUM (Case WHEN (eyeTissueRecovered.NsftStroma & 2 = 2)
							THEN 1
							ELSE 0
						END) as 'Scar',
						SUM (Case WHEN (eyeTissueRecovered.NsftStroma & 4 = 4)
							THEN 1
							ELSE 0
						END) as 'Infiltrate',
						SUM (Case WHEN (eyeTissueRecovered.NsftStroma & 8 = 8)
							THEN 1
							ELSE 0
						END) as 'ForeignBody',
						SUM (Case WHEN (eyeTissueRecovered.NsftStromaOther = 1)
							THEN 1
							ELSE 0
						END) as 'NsftStromaOther',
						SUM (Case WHEN (eyeTissueRecovered.NsftDescemetsMembrane = 1)
							THEN 1
							ELSE 0
						END) as 'NsftDescemetsMembrane',
						 SUM (Case WHEN (eyeTissueRecovered.NsftEndothelium = 1)
							THEN 1
							ELSE 0
						END) as 'NsftEndothelium',
						--
						--null as 'Quality Issue',
						--
						SUM (Case WHEN (eyeTissueRecovered.NsftQuality & 1 = 1)
							THEN 1
							ELSE 0
						END) as 'Storage',
						 SUM (Case WHEN (eyeTissueRecovered.NsftQuality & 2 = 2)
							THEN 1
							ELSE 0
						END) as 'Labeling',
						   SUM (Case WHEN (eyeTissueRecovered.NsftQuality & 4 = 4)
							THEN 1
							ELSE 0
						END) as 'Processing',
						SUM (Case WHEN (eyeTissueRecovered.NsftQuality & 8 = 8)
							THEN 1
							ELSE 0
						END) as 'SupplyOrReagent',
						SUM (Case WHEN (eyeTissueRecovered.NsftQuality & 16 = 16)
							THEN 1
							ELSE 0
						END) as 'EnvironmentalControl',
						   SUM (Case WHEN (eyeTissueRecovered.NsftQualityOther = 1)
							THEN 1
							ELSE 0
						END) as 'NsftQualityOther',
				
						--
						-- n'Reasons released tissue was not transplanted',
						--
						SUM (Case WHEN (eyeTissueRecovered.NsftPostRelease & 1 = 1)
							THEN 1
							ELSE 0
						END) as 'TransportationIssue',
						SUM (Case WHEN (eyeTissueRecovered.NsftPostRelease & 2 = 2)
							THEN 1
							ELSE 0
						END) as 'SurgeonIssue',
						SUM (Case WHEN (eyeTissueRecovered.NsftPostRelease & 4 = 4)
							THEN 1
							ELSE 0
						END) as 'RecipientIssue',
						SUM (Case WHEN (eyeTissueRecovered.NsftPostRelease & 8 = 8)
							THEN 1
							ELSE 0
						END) as 'ReturnedUnableToPlaceAgain',
						SUM (Case WHEN (eyeTissueRecovered.NsftPostRelease & 16 = 16)
							THEN 1
							ELSE 0
						END) as 'DonorInformationNotAvailable',
						SUM (Case WHEN (eyeTissueRecovered.NsftPostRelease & 32 = 32)
							THEN 1
							ELSE 0
						END) as 'Expired',
						SUM (Case WHEN (eyeTissueRecovered.NsftPostRelease & 64 = 64)
							THEN 1
							ELSE 0
						END) as 'TissueDamagedDuringProcessing',
						SUM (Case WHEN (eyeTissueRecovered.NsftPostReleaseOther = 1)
							THEN 1
							ELSE 0
						END) as 'NsftPostReleaseOther',                
						COUNT(CASE WHEN eyeTissueRecovered.NsftPostRelease & 1 = 1
								   OR eyeTissueRecovered.NsftPostRelease & 2 = 2
								   OR eyeTissueRecovered.NsftPostRelease & 4 = 4
								   OR eyeTissueRecovered.NsftPostRelease & 8 = 8
								   OR eyeTissueRecovered.NsftPostRelease & 16 = 16
								   OR eyeTissueRecovered.NsftPostRelease & 32 = 32
								   OR eyeTissueRecovered.NsftPostRelease & 64 = 64
								   OR eyeTissueRecovered.NsftPostReleaseOther = 1
							  THEN 1
							  END) TotalDiscardedTissues,
						COUNT(CASE WHEN eyeTissueRecovered.RecoveryIntent = 1 AND (eyeTissueRecovered.NsftQuality & 1 = 1
								   OR eyeTissueRecovered.NsftQuality & 2 = 2
								   OR eyeTissueRecovered.NsftQuality & 4 = 4
								   OR eyeTissueRecovered.NsftQuality & 8 = 8
								   OR eyeTissueRecovered.NsftQuality & 16 = 16
								   OR eyeTissueRecovered.NsftQualityOther = 1
								   OR eyeTissueRecovered.NsftSerology & 1 = 1
								   OR eyeTissueRecovered.NsftSerology & 2 = 2
								   OR eyeTissueRecovered.NsftSerology & 4 = 4
								   OR eyeTissueRecovered.NsftSerology & 8 = 8
								   OR eyeTissueRecovered.NsftSerology & 16 = 16
								   OR eyeTissueRecovered.NsftSerology & 32 = 32
								   OR eyeTissueRecovered.NsftSerology & 64 = 64
								   OR eyeTissueRecovered.NsftSerology & 128 = 128
								   OR eyeTissueRecovered.NsftSerologyOther = 1
								   OR eyeTissueRecovered.NsftSerologyOtherCommunicable = 1
								   OR eyeTissueRecovered.NsftMedicalRecord & 1 = 1
								   OR eyeTissueRecovered.NsftMedicalRecord & 2 = 2
								   OR eyeTissueRecovered.NsftMedicalRecord & 4 = 4
								   OR eyeTissueRecovered.NsftMedicalRecord & 8 = 8
								   OR eyeTissueRecovered.NsftMedicalRecord & 16 = 16
								   OR eyeTissueRecovered.NsftMedicalRecordOther = 1
								   OR eyeTissueRecovered.NsftMedSocInterview & 1 = 1
								   OR eyeTissueRecovered.NsftMedSocInterview & 2 = 2
								   OR eyeTissueRecovered.NsftMedSocInterviewOther = 1
								   OR eyeTissueRecovered.NsftBodyExam = 1
								   OR eyeTissueRecovered.NsftEpithelium = 1
								   OR eyeTissueRecovered.NsftStroma & 1 = 1
								   OR eyeTissueRecovered.NsftStroma & 2 = 2
								   OR eyeTissueRecovered.NsftStroma & 4 = 4
								   OR eyeTissueRecovered.NsftStroma & 8 = 8
								   OR eyeTissueRecovered.NsftDescemetsMembrane = 1
								   OR eyeTissueRecovered.NsftEndothelium = 1)
							  THEN 1
							  END) TotalDiscardedTissuesNotReleased
				
				 FROM #referrals r WITH(NOLOCK) 
				 JOIN (SELECT etr.*
						FROM EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
						LEFT JOIN EyeRecovery.EyeTissueRecovered parent WITH(NOLOCK)
							ON etr.ID = parent.ParentID
						WHERE parent.ID IS NULL
						AND (etr.RecoveryTissueType = 'WE' OR (etr.RecoveryTissueType = 'CN' AND etr.RecoveryTissueSubType = 'WCN'))) eyeTissueRecovered
					ON eyeTissueRecovered.CaseFileId = r.ReferralID 
					AND r.CaseFileType='Referral'
				GROUP BY r.MonthText) d
			UNPIVOT
			(ReferralCount
			 FOR [Type] IN 
			 ([HIVAntibody],[HIVNucleicAcidTest],[HepatitisBSurfaceAntigen],[HepatitisBCoreAntibody],[HepatitisCAntibody],[HepatitisCNucleicAcidTest],[Syphilis],[HTLVAntibody],[NsftSerologyOther],[NsftSerologyOtherCommunicable],[DementiaNeurologicalIssues],[SepsisPositiveBloodCultures],[SepsisOther],[PlasmaDilution],[UnknownCauseOfDeath],[NsftMedicalRecordOther],[Travel],[MedSocDementiaNeurologicalIssues],[NsftMedSocInterviewOther],[NsftBodyExam],[NsftEpithelium],[PriorRefractiveSurgery],[Scar],[Infiltrate],[ForeignBody],[NsftStromaOther],[NsftDescemetsMembrane],[NsftEndothelium],[Storage],[Labeling],[Processing],[SupplyOrReagent],[EnvironmentalControl],[NsftQualityOther],[TransportationIssue],[SurgeonIssue],[RecipientIssue],[ReturnedUnableToPlaceAgain],[DonorInformationNotAvailable],[Expired],[TissueDamagedDuringProcessing],[NsftPostReleaseOther],[TotalDiscardedTissues],[TotalDiscardedTissuesNotReleased])) u) Unpvt
			PIVOT
			(MAX(ReferralCount)
			 FOR MonthText
			 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 
	
	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'CorneasSuitableForReleased' Label, '04.E', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN Tissues.ID IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType = 'CN' --Corneas Only
			AND InventoryStatus = 'R' --Approval Status = Released
			AND (ApprovedOutcomes IS NOT NULL and  ApprovedOutcomes = 1) -- Transplant
		LEFT JOIN (SELECT etr.ID
				FROM EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
				LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
					ON etr.ID = child.ParentID
				WHERE child.ID IS NULL) Tissues  --Do not count Parent tissue if child tissue exists
			ON etr.ID = Tissues.ID		
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'SuitableForPenetratingKeratoplasty' Label, '04.E.01', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN Tissues.ID IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType = 'CN' --Corneas Only
			AND InventoryStatus = 'R' --Approval Status = Released
			AND (ApprovedOutcomes IS NOT NULL and  ApprovedOutcomes = 1) -- Transplant
		LEFT JOIN (SELECT etr.ID
				FROM EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
				LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
					ON etr.ID = child.ParentID
				WHERE child.ID IS NULL) Tissues  --Do not count Parent tissue if child tissue exists
			ON etr.ID = Tissues.ID
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON @usageType = e.EnumerationTypeID 
			AND e.[Description] IN ('PK', 'PKP')
			AND CAST(etr.ApprovedUsages AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'SuitableForEndothelialKeratoplasty' Label, '04.E.02', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN Tissues.ID IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType = 'CN' --Corneas Only
			AND InventoryStatus = 'R' --Approval Status = Released
			AND (ApprovedOutcomes IS NOT NULL and  ApprovedOutcomes = 1) -- Transplant
		LEFT JOIN (SELECT etr.ID
				FROM EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
				LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
					ON etr.ID = child.ParentID
				WHERE child.ID IS NULL) Tissues  --Do not count Parent tissue if child tissue exists
			ON etr.ID = Tissues.ID
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON @usageType = e.EnumerationTypeID 
			AND e.[Description] = 'EK'
			AND ISNUMERIC(e.Value) = 1
			AND CAST(etr.ApprovedUsages AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'SuitableForKeratolimbalAllograft' Label, '04.E.03', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN Tissues.ID IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType = 'CN' --Corneas Only
			AND InventoryStatus = 'R' --Approval Status = Released
			AND (ApprovedOutcomes IS NOT NULL and  ApprovedOutcomes = 1) -- Transplant
		LEFT JOIN (SELECT etr.ID
				FROM EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
				LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
					ON etr.ID = child.ParentID
				WHERE child.ID IS NULL) Tissues  --Do not count Parent tissue if child tissue exists
			ON etr.ID = Tissues.ID
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON @usageType = e.EnumerationTypeID 
			AND e.[Description] = 'KLA'
			AND CAST(etr.ApprovedUsages AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'SuitableForAnteriorLamellarKeratoplasty' Label, '04.E.04', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN Tissues.ID IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType = 'CN' --Corneas Only
			AND InventoryStatus = 'R' --Approval Status = Released
			AND (ApprovedOutcomes IS NOT NULL and  ApprovedOutcomes = 1) -- Transplant
		LEFT JOIN (SELECT etr.ID
				FROM EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
				LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
					ON etr.ID = child.ParentID
				WHERE child.ID IS NULL) Tissues  --Do not count Parent tissue if child tissue exists
			ON etr.ID = Tissues.ID
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON @usageType = e.EnumerationTypeID 
			AND e.[Description] = 'ALK'
			AND CAST(etr.ApprovedUsages AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'SuitableForOtherSurgicalUse' Label, '04.E.05', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,COUNT(DISTINCT CASE WHEN Tissues.ID IS NOT NULL AND e.Value IS NOT NULL THEN etr.ID END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType = 'CN' --Corneas Only
			AND InventoryStatus = 'R' --Approval Status = Released
			AND (ApprovedOutcomes IS NOT NULL and  ApprovedOutcomes = 1) -- Transplant
		LEFT JOIN (SELECT etr.ID
				FROM EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
				LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
					ON etr.ID = child.ParentID
				WHERE child.ID IS NULL) Tissues  --Do not count Parent tissue if child tissue exists
			ON etr.ID = Tissues.ID
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON @usageType = e.EnumerationTypeID 
			AND e.[Description] IN ('K-Pro','Glaucoma shunt patching','Other Keratoplasty (e.g. experimental surgery type)','Unknown or Unspecified','Glaucoma shunt patch or other non-keratoplasty use')
			AND CAST(etr.ApprovedUsages AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'IntermediateTermCorneas' Label, '05.A', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,COUNT(DISTINCT CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NOT NULL AND ipm.Value IS NOT NULL THEN etr.ID END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType = 'CN' --Corneas Only
			AND etr.RecoveryTissueSubType = 'WCN' --Approval Status = Released
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK)
			ON etr.StorageMedia = ipm.Value
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'IntermediateTermCorneaSegments' Label, '05.B', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NOT NULL AND ipm.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType = 'CN' --Corneas Only
			AND etr.RecoveryTissueSubType = 'WCN' --Approval Status = Released
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType <> 'WCN'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK)
			ON child.StorageMedia = ipm.Value
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'OpticalOrElectivePK' Label, '05.C.01.A', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('PK','PKP')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('Optical','Elective')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'EmergencyOrTectonicFullThickness' Label, '05.C.01.B', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('PK','PKP')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('Emergency','Tectonic Full Thickness')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DsekDsaekDlek' Label, '05.C.02.A', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('EK')
			AND ISNUMERIC(e.Value) = 1
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('DSEK','DSAEK','DLEK')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DmekDmaek' Label, '05.C.02.B', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('EK')
			AND ISNUMERIC(e.Value) = 1
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('DMEK','DMAEK')
			--AND ISNUMERIC(ey.Value) = 1
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		--LEFT JOIN dbo.OrganizationInGroup oig WITH(NOLOCK)
		--	ON @organizationID = oig.OrganizationID
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DALK' Label, '05.C.03.A', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('ALK')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('DALK')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'SALK' Label, '05.C.03.B', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('ALK')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('SALK')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'OtherALK' Label, '05.C.03.C', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('ALK')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('Other ALK')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'KLA' Label, '05.C.04', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('KLA')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'K-Pro' Label, '05.C.05', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('K-Pro')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'GlaucomaPatchOther' Label, '05.C.06', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('Glaucoma shunt patch or other non-keratoplasty use')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'OtherKeratoplasty' Label, '05.C.07', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('Other Keratoplasty (e.g. experimental surgery type)')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'UnknownUnspecified' Label, '05.C.08', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.US = 1 --Mapped as a US location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('Unknown or Unspecified')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p


	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'OpticalOrElectivePK' Label, '05.D.01.A', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('PK','PKP')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('Optical','Elective')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'EmergencyOrTectonicFullThickness' Label, '05.D.01.B', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('PK','PKP')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('Emergency','Tectonic Full Thickness')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DsekDsaekDlek' Label, '05.D.02.A', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('EK')
			AND ISNUMERIC(e.Value) = 1
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('DSEK','DSAEK','DLEK')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DmekDmaek' Label, '05.D.02.B', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('EK')
			AND ISNUMERIC(e.Value) = 1
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('DMEK','DMAEK')
			--AND ISNUMERIC(ey.Value) = 1
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DALK' Label, '05.D.03.A', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('ALK')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('DALK')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'SALK' Label, '05.D.03.B', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('ALK')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('SALK')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'OtherALK' Label, '05.D.03.C', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL AND ey.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('ALK')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN dbo.EnumerationValue ey WITH(NOLOCK)
			ON ey.EnumerationTypeID = @usageDetailType
			AND ey.[Description] IN ('Other ALK')
			AND CAST(rq.SurgerySubType AS VARCHAR) & CAST(ey.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'KLA' Label, '05.D.04', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('KLA')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'K-Pro' Label, '05.D.05', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('K-Pro')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'GlaucomaPatchOther' Label, '05.D.06', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('Glaucoma shunt patch or other non-keratoplasty use')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'OtherKeratoplasty' Label, '05.D.07', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('Other Keratoplasty (e.g. experimental surgery type)')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'OtherUnspecified' Label, '05.D.08', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND child.ParentID IS NULL AND ipm.Value IS NOT NULL AND gm.Value IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.ID = child.ParentID
			AND child.RecoveryTissueType = 'CN'
			AND child.RecoveryTissueSubType = 'GB'
		LEFT JOIN dbo.EBAnnualReportIntermediateTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EBAnnualReportGeographicMap gm WITH(NOLOCK)
			ON rq.IntendedSubOutcome = gm.Value
			AND (gm.OrganizationID = @organizationID OR (gm.OrganizationID IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.EBAnnualReportGeographicMap WITH(NOLOCK) WHERE OrganizationID = @organizationID)))
			AND gm.International = 1 --Mapped as an international location
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('Unknown or Unspecified')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'PreservedForTransplant' Label, '06.A', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND ipm.Value IS NOT NULL AND etr.ParentID IS NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
			AND 
				(Case When (etr.ApprovedOutcomes  IS NOT NULL AND etr.ApprovedOutcomes != 0) Then etr.ApprovedOutcomes  
				 When (etr.ApprovedOutcomes  IS NULL or etr.ApprovedOutcomes = 0) Then etr.RecoveryIntent
				end) = 1
		LEFT JOIN dbo.EBAnnualReportLongTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value		
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DistributedForKeratoplasty' Label, '06.B.01', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND ipm.Value IS NOT NULL AND rq.ID IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN dbo.EBAnnualReportLongTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('PK','PKP','EK','ALK','KLA','K-Pro','Other Keratoplasty (e.g. experimental surgery type)')
			AND ISNUMERIC(e.Value) = 1
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.id = child.ParentID
		WHERE child.ID IS NULL
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p


	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DistributedForGlaucomaShunt' Label, '06.B.02', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND ipm.Value IS NOT NULL AND rq.ID IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN dbo.EBAnnualReportLongTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('Glaucoma shunt patch or other non-keratoplasty use')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.id = child.ParentID
		WHERE child.ID IS NULL
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p


	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'DistributedForOther' Label, '06.B.03', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND ipm.Value IS NOT NULL AND rq.ID IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN dbo.EBAnnualReportLongTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.EnumerationTypeID = @usageType
			AND e.[Description] IN ('Unknown or Unspecified')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.id = child.ParentID
		WHERE child.ID IS NULL
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p


	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'LongTermForwarded' Label, '06.C', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,COUNT(DISTINCT CASE WHEN etr.CaseFileID IS NOT NULL AND ipm.Value IS NOT NULL AND o.TissueID IS NOT NULL THEN o.TissueId END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('CN', 'WE') --Corneas or Whole Eyes
		LEFT JOIN dbo.EBAnnualReportLongTermPreservativeMap ipm WITH(NOLOCK) --Mapping table for intermediate preservative
			ON etr.StorageMedia = ipm.Value
		LEFT JOIN EyeDist.Offer o WITH(NOLOCK)
			ON etr.ID = o.TissueID
			AND (ISNULL(o.OfferedToId, '00000000-0000-0000-0000-000000000000') <> '00000000-0000-0000-0000-000000000000' OR ISNULL(o.OfferedToOrganizationId, '00000000-0000-0000-0000-000000000000') <> '00000000-0000-0000-0000-000000000000')
			AND o.Response='Accepted'
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.id = child.ParentID
		WHERE child.ID IS NULL
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p


	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'ScleraPreservedForTransplant' Label, '06.D', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('S') --Sclera
			AND 
				(Case When (etr.ApprovedOutcomes  IS NOT NULL AND etr.ApprovedOutcomes != 0) Then etr.ApprovedOutcomes  
				 When (etr.ApprovedOutcomes  IS NULL or etr.ApprovedOutcomes = 0) Then etr.RecoveryIntent
				end) = 1
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.id = child.ParentID
		WHERE child.ID IS NULL
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'ScleraDistributedForProsthesis' Label, '06.E.01', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rq.ID IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('S') --Sclera
			AND 
				(Case When (etr.ApprovedOutcomes  IS NOT NULL AND etr.ApprovedOutcomes != 0) Then etr.ApprovedOutcomes  
				 When (etr.ApprovedOutcomes  IS NULL or etr.ApprovedOutcomes = 0) Then etr.RecoveryIntent
				end) = 1
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.[Description] IN ('Prosthesis following enucleation')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
			AND e.EnumerationTypeID = @usageType
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.id = child.ParentID
		WHERE child.ID IS NULL
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p


	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'ScleraDistributedForGlaucomaShunt' Label, '06.E.02', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rq.ID IS NOT NULL AND e.Value IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('S') --Sclera
			AND 
				(Case When (etr.ApprovedOutcomes  IS NOT NULL AND etr.ApprovedOutcomes != 0) Then etr.ApprovedOutcomes  
				 When (etr.ApprovedOutcomes  IS NULL or etr.ApprovedOutcomes = 0) Then etr.RecoveryIntent
				end) = 1
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON e.[Description] IN ('Glaucoma shunt patching')
			AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
			AND e.EnumerationTypeID = @usageType
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.id = child.ParentID
		WHERE child.ID IS NULL
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'ScleraDistributedForOther' Label, '06.E.03', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rq.ID IS NOT NULL AND (e.[Description] = 'Other surgical uses' OR rq.SurgeryType IS NULL) THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('S') --Sclera
			AND 
				(Case When (etr.ApprovedOutcomes  IS NOT NULL AND etr.ApprovedOutcomes != 0) Then etr.ApprovedOutcomes  
				 When (etr.ApprovedOutcomes  IS NULL or etr.ApprovedOutcomes = 0) Then etr.RecoveryIntent
				end) = 1
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '1' --Transplant
		LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
			ON CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
			AND e.EnumerationTypeID = @usageType
		LEFT JOIN EyeRecovery.EyeTissueRecovered child WITH(NOLOCK)
			ON etr.id = child.ParentID
		WHERE child.ID IS NULL
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'ScleraForwarded' Label, '06.F', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,COUNT(DISTINCT o.TissueID) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
			AND etr.RecoveryTissueType IN ('S') --Sclera
			AND 
				(Case When (etr.ApprovedOutcomes  IS NOT NULL AND etr.ApprovedOutcomes != 0) Then etr.ApprovedOutcomes  
				 When (etr.ApprovedOutcomes  IS NULL or etr.ApprovedOutcomes = 0) Then etr.RecoveryIntent
				end) = 1
		LEFT JOIN EyeDist.Offer o WITH(NOLOCK)
			ON etr.ID = o.TissueID
			AND (ISNULL(o.OfferedToId, '00000000-0000-0000-0000-000000000000') <> '00000000-0000-0000-0000-000000000000' OR ISNULL(o.OfferedToOrganizationId, '00000000-0000-0000-0000-000000000000') <> '00000000-0000-0000-0000-000000000000')
			AND o.Response='Accepted'
			AND o.DeletedOn IS NULL
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'TissuesProvidedForResearch' Label, '07.A', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rq.ID IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '2' --Research
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'TissuesProvidedForTraining' Label, '07.B', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rq.ID IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON etr.DistributionRequestID = rq.ID
			AND rq.IntendedOutcome = '4' --Training
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'TransplantImportTissue' Label, '09.A', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID
			AND etr.ReasonForImport = 'Import' --Imported Tissue
			AND ((etr.RecoveryTissueType = 'CN' AND etr.RecoveryTissueSubType = 'WCN')
				  OR etr.RecoveryTissueType = 'WE')
			AND etr.Outcome = 1 --Transplant
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 'TransplantExportEBAA' Label, '09.B',@reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND o.TissueID IS NOT NULL AND rq.ID IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID
			AND (ReasonForImport is null)
			AND ((etr.RecoveryTissueType = 'CN' AND etr.RecoveryTissueSubType = 'WCN')
				  OR etr.RecoveryTissueType = 'WE')
		LEFT JOIN EyeDist.Offer o WITH(NOLOCK)
			ON etr.ID = o.TissueID
			AND (ISNULL(o.OfferedToId, '00000000-0000-0000-0000-000000000000') <> '00000000-0000-0000-0000-000000000000' OR ISNULL(o.OfferedToOrganizationId, '00000000-0000-0000-0000-000000000000') <> '00000000-0000-0000-0000-000000000000')
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON o.RequestID = rq.ID
			AND rq.RequestingOrganizationAccreditation = 1
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	--NOTE:  The "EBAA Accredited" field does not yet exist.  Therefore, 09.B and 09.C are placeholders returning the same data until the new field is created.
	SELECT 'TransplantExportNONEBAA' Label, '09.C', @reportYear, NULL as YearCalculation, *
	FROM

		(SELECT 
			 r.MonthText
			,SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND o.TissueID IS NOT NULL AND rq.ID IS NOT NULL THEN 1 ELSE 0 END) ReferralCount
		FROM #referrals r WITH(NOLOCK)
		LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
			ON r.ReferralID = etr.CaseFileID
			AND (ReasonForImport is null)
			AND ((etr.RecoveryTissueType = 'CN' AND etr.RecoveryTissueSubType = 'WCN')
				  OR etr.RecoveryTissueType = 'WE')
		LEFT JOIN EyeDist.Offer o WITH(NOLOCK)
			ON etr.ID = o.TissueID
			AND (ISNULL(o.OfferedToId, '00000000-0000-0000-0000-000000000000') <> '00000000-0000-0000-0000-000000000000' OR ISNULL(o.OfferedToOrganizationId, '00000000-0000-0000-0000-000000000000') <> '00000000-0000-0000-0000-000000000000')
		LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
			ON o.RequestID = rq.ID
			AND rq.RequestingOrganizationAccreditation = 0
		GROUP BY r.MonthText) d
		PIVOT
		(MAX(ReferralCount)
		 FOR MonthText
		 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	--Below is Section X.  Easier to query all at once using an UNPIVOT and PIVOT.
	SELECT 
		 [Type] Label
		,Sort = CASE [Type] WHEN 'A. Post-cataract surgery edema' THEN '10.A'
							WHEN 'B. Keratoconus' THEN '10.B'
							WHEN 'C. Fuchs'' Dystrophy' THEN '10.C'
							WHEN 'D. Repeat corneal transplant' THEN '10.D'
							WHEN 'E. Other degenerations or dystrophies' THEN '10.E'
							WHEN 'F. Refractive' THEN '10.F'
							WHEN 'G. Microbial Keratitis' THEN '10.G'
							WHEN 'H. Mechanical (non-surgical) or Chemical Trauma' THEN '10.H'
							WHEN 'I. Congenital opacities' THEN '10.I'
							WHEN 'J. Pterygium' THEN '10.J'
							WHEN 'K. Noninfectious Ulcerative Keratitis, Thinning or Perforation' THEN '10.K'
							WHEN 'L. Other Causes of Corneal Opacification or Distortion' THEN '10.L'
							WHEN 'M. Other Causes of Endothelial Dysfunction' THEN '10.M'
							WHEN 'Z. Unknown, unreported, or unspecified' THEN '10.Z'
							END
		,@reportYear
		,NULL as YearCalculation
		,[January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December]
	FROM
			(SELECT *
			 FROM (        		  
				SELECT  r.MonthText,
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'A.' THEN 1 END), 0) [A. Post-cataract surgery edema],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'B.' THEN 1 END), 0) [B. Keratoconus],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'C.' THEN 1 END), 0) [C. Fuchs' Dystrophy],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'D.' THEN 1 END), 0) [D. Repeat corneal transplant],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'E.' THEN 1 END), 0) [E. Other degenerations or dystrophies],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'F.' THEN 1 END), 0) [F. Refractive],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'G.' THEN 1 END), 0) [G. Microbial Keratitis],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'H.' THEN 1 END), 0) [H. Mechanical (non-surgical) or Chemical Trauma],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'I.' THEN 1 END), 0) [I. Congenital opacities],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'J.' THEN 1 END), 0) [J. Pterygium],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'K.' THEN 1 END), 0) [K. Noninfectious Ulcerative Keratitis, Thinning or Perforation],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'L.' THEN 1 END), 0) [L. Other Causes of Corneal Opacification or Distortion],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'M.' THEN 1 END), 0) [M. Other Causes of Endothelial Dysfunction],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'Z.' THEN 1 END), 0) [Z. Unknown, unreported, or unspecified]
				FROM #referrals r WITH(NOLOCK)
				LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
					ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
				LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
					ON etr.DistributionRequestID = rq.ID
					AND rq.[Status] IN ('Placed', 'Shipped')
					AND rq.TissueTypeRequested = 'CN'
					AND rq.TissueSubTypeRequested = 'WCN'
				LEFT JOIN EyeDist.EyeRecipient rp WITH(NOLOCK)
					ON rq.EyeRecipientID = rp.ID
				LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
					ON e.EnumerationTypeID = @usageType
					AND e.[Description] IN ('PK','PKP')
					AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
				LEFT JOIN dbo.EnumerationValue dx WITH(NOLOCK)
					ON dx.EnumerationTypeID = @dxType
					AND rp.PreOpDiagnosis = dx.Value
				GROUP BY r.MonthText) d
			UNPIVOT
			(ReferralCount
			 FOR [Type] IN 
			 ([A. Post-cataract surgery edema],[B. Keratoconus],[C. Fuchs' dystrophy],[D. Repeat corneal transplant],[E. Other degenerations or dystrophies],[F. Refractive],[G. Microbial Keratitis],[H. Mechanical (non-surgical) or Chemical Trauma],[I. Congenital opacities],[J. Pterygium],[K. Noninfectious Ulcerative Keratitis, Thinning or Perforation],[L. Other Causes of Corneal Opacification or Distortion],[M. Other Causes of Endothelial Dysfunction],[Z. Unknown, unreported, or unspecified])) u) Unpvt
			PIVOT
			(MAX(ReferralCount)
			 FOR MonthText
			 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	--Below is Section XI.  Easier to query all at once using an UNPIVOT and PIVOT.
	SELECT 
		 [Type] Label
		,Sort = CASE [Type] WHEN 'A. Post-cataract surgery edema' THEN '11.A'
							WHEN 'B. Keratoconus' THEN '11.B'
							WHEN 'C. Fuchs'' Dystrophy' THEN '11.C'
							WHEN 'D. Repeat corneal transplant' THEN '11.D'
							WHEN 'E. Other degenerations or dystrophies' THEN '11.E'
							WHEN 'F. Refractive' THEN '11.F'
							WHEN 'G. Microbial Keratitis' THEN '11.G'
							WHEN 'H. Mechanical (non-surgical) or Chemical Trauma' THEN '11.H'
							WHEN 'I. Congenital opacities' THEN '11.I'
							WHEN 'J. Pterygium' THEN '11.J'
							WHEN 'K. Noninfectious Ulcerative Keratitis, Thinning or Perforation' THEN '11.K'
							WHEN 'L. Other Causes of Corneal Opacification or Distortion' THEN '11.L'
							WHEN 'M. Other Causes of Endothelial Dysfunction' THEN '11.M'
							WHEN 'Z. Unknown, unreported, or unspecified' THEN '11.Z'
							END
		,@reportYear
		,NULL as YearCalculation
		,[January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December]
	FROM
			(SELECT *
			 FROM (
				  
				SELECT  r.MonthText,
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'B.' THEN 1 END), 0) [B. Keratoconus],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'D.' THEN 1 END), 0) [D. Repeat corneal transplant],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'E.' THEN 1 END), 0) [E. Other degenerations or dystrophies],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'F.' THEN 1 END), 0) [F. Refractive],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'G.' THEN 1 END), 0) [G. Microbial Keratitis],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'H.' THEN 1 END), 0) [H. Mechanical (non-surgical) or Chemical Trauma],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'I.' THEN 1 END), 0) [I. Congenital opacities],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'J.' THEN 1 END), 0) [J. Pterygium],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'K.' THEN 1 END), 0) [K. Noninfectious Ulcerative Keratitis, Thinning or Perforation],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'L.' THEN 1 END), 0) [L. Other Causes of Corneal Opacification or Distortion],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'Z.' THEN 1 END), 0) [Z. Unknown, unreported, or unspecified]
				FROM #referrals r WITH(NOLOCK)
				LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
					ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
				LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
					ON etr.DistributionRequestID = rq.ID
					AND rq.[Status] IN ('Placed', 'Shipped')
					AND rq.TissueTypeRequested = 'CN'
					AND rq.TissueSubTypeRequested = 'WCN'
				LEFT JOIN EyeDist.EyeRecipient rp WITH(NOLOCK)
					ON rq.EyeRecipientID = rp.ID
				LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
					ON e.EnumerationTypeID = @usageType
					AND e.[Description] IN ('ALK')
					AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
				LEFT JOIN dbo.EnumerationValue dx WITH(NOLOCK)
					ON dx.EnumerationTypeID = @dxType
					AND rp.PreOpDiagnosis = dx.Value
				GROUP BY r.MonthText) d
			UNPIVOT
			(ReferralCount
			 FOR [Type] IN 
			 ([B. Keratoconus],[D. Repeat corneal transplant],[E. Other degenerations or dystrophies],[F. Refractive],[G. Microbial Keratitis],[H. Mechanical (non-surgical) or Chemical Trauma],[I. Congenital opacities],[J. Pterygium],[K. Noninfectious Ulcerative Keratitis, Thinning or Perforation],[L. Other Causes of Corneal Opacification or Distortion],[Z. Unknown, unreported, or unspecified])) u) Unpvt
			PIVOT
			(MAX(ReferralCount)
			 FOR MonthText
			 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	--Below is Section XII.  Easier to query all at once using an UNPIVOT and PIVOT.
	SELECT 
		 [Type] Label
		,Sort = CASE [Type] WHEN 'A. Post-cataract surgery edema' THEN '12.A'
							WHEN 'B. Keratoconus' THEN '12.B'
							WHEN 'C. Fuchs'' Dystrophy' THEN '12.C'
							WHEN 'D. Repeat corneal transplant' THEN '12.D'
							WHEN 'E. Other degenerations or dystrophies' THEN '12.E'
							WHEN 'F. Refractive' THEN '12.F'
							WHEN 'G. Microbial Keratitis' THEN '12.G'
							WHEN 'H. Mechanical (non-surgical) or Chemical Trauma' THEN '12.H'
							WHEN 'I. Congenital opacities' THEN '12.I'
							WHEN 'J. Pterygium' THEN '12.J'
							WHEN 'K. Noninfectious Ulcerative Keratitis, Thinning or Perforation' THEN '12.K'
							WHEN 'L. Other Causes of Corneal Opacification or Distortion' THEN '12.L'
							WHEN 'M. Other Causes of Endothelial Dysfunction' THEN '12.M'
							WHEN 'Z. Unknown, unreported, or unspecified' THEN '12.Z'
							END
		,@reportYear
		,NULL as YearCalculation
		,[January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December]
	FROM
			(SELECT *
			 FROM (
				  
				SELECT  r.MonthText,
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'A.' THEN 1 END), 0) [A. Post-cataract surgery edema],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'C.' THEN 1 END), 0) [C. Fuchs' Dystrophy],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'D.' THEN 1 END), 0) [D. Repeat corneal transplant],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'M.' THEN 1 END), 0) [M. Other Causes of Endothelial Dysfunction],
						ISNULL(SUM(CASE WHEN etr.CaseFileID IS NOT NULL AND rp.ID IS NOT NULL AND e.Value IS NOT NULL AND LEFT(dx.[Description], 2) = 'Z.' THEN 1 END), 0) [Z. Unknown, unreported, or unspecified]
				FROM #referrals r WITH(NOLOCK)
				LEFT JOIN EyeRecovery.EyeTissueRecovered etr WITH(NOLOCK)
					ON r.ReferralID = etr.CaseFileID AND r.CaseFileType='Referral'
				LEFT JOIN EyeDist.Request rq WITH(NOLOCK)
					ON etr.DistributionRequestID = rq.ID
					AND rq.[Status] IN ('Placed', 'Shipped')
					AND rq.TissueTypeRequested = 'CN'
					AND rq.TissueSubTypeRequested = 'WCN'
				LEFT JOIN EyeDist.EyeRecipient rp WITH(NOLOCK)
					ON rq.EyeRecipientID = rp.ID
				LEFT JOIN dbo.EnumerationValue e WITH(NOLOCK)
					ON e.EnumerationTypeID = @usageType
					AND e.[Description] IN ('EK')
					AND ISNUMERIC(e.Value) = 1
					AND CAST(rq.SurgeryType AS VARCHAR) & CAST(e.Value AS INT) > 0 --Bitwise comparison
				LEFT JOIN dbo.EnumerationValue dx WITH(NOLOCK)
					ON dx.EnumerationTypeID = @dxType
					AND rp.PreOpDiagnosis = dx.Value
				GROUP BY r.MonthText) d
			UNPIVOT
			(ReferralCount
			 FOR [Type] IN 
			 ([A. Post-cataract surgery edema],[C. Fuchs' dystrophy],[D. Repeat corneal transplant],[M. Other Causes of Endothelial Dysfunction],[Z. Unknown, unreported, or unspecified])) u) Unpvt
			PIVOT
			(MAX(ReferralCount)
			 FOR MonthText
			 IN ([January],[February],[March],[April],[May],[June],[July],[August],[September],[October],[November],[December])) p	 


-------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  Validations and Calculations
-------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT
		 'TotalDonors'
		,'02.A'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '02.A.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '02.A.02'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT
		 'CalculationE'
		,'04.B.01'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) - ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) - ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) - ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) - ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) - ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) - ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) - ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) - ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) - ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) - ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) - ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) - ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '02.B'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.B'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT
		 'CalculationA'
		,'02.D'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '02.B'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '02.C'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT
		 'ValidationA'
		,'02.E'
		,@reportYear
		,Case WHEN (ISNULL(c.January, 0) + ISNULL(c.February, 0) + ISNULL(c.March, 0) + ISNULL(c.April, 0) + ISNULL(c.May, 0) + ISNULL(c.June, 0) + 
		ISNULL(c.July, 0) + ISNULL(c.August, 0) + ISNULL(c.September, 0) + ISNULL(c.October, 0) + ISNULL(c.November, 0) + ISNULL(c.December, 0)) = 0
		THEN 0
		ELSE
		(
		(ISNULL(b.January, 0) + ISNULL(b.February, 0) + ISNULL(b.March, 0) + ISNULL(b.April, 0) + ISNULL(b.May, 0) + ISNULL(b.June, 0) + 
		ISNULL(b.July, 0) + ISNULL(b.August, 0) + ISNULL(b.September, 0) + ISNULL(b.October, 0) + ISNULL(b.November, 0) + ISNULL(b.December, 0))/
		
		(ISNULL(c.January, 0) + ISNULL(c.February, 0) + ISNULL(c.March, 0) + ISNULL(c.April, 0) + ISNULL(c.May, 0) + ISNULL(c.June, 0) + 
		ISNULL(c.July, 0) + ISNULL(c.August, 0) + ISNULL(c.September, 0) + ISNULL(c.October, 0) + ISNULL(c.November, 0) + ISNULL(c.December, 0))
		)
		END
		as YearCalculation
		,CASE WHEN c.January = 0 THEN 0 ELSE CAST(b.January AS DECIMAL(10,4)) / c.January END
		,CASE WHEN c.February = 0 THEN 0 ELSE CAST(b.February AS DECIMAL(10,4)) / c.February END
		,CASE WHEN c.March = 0 THEN 0 ELSE CAST(b.March AS DECIMAL(10,4)) / c.March END
		,CASE WHEN c.April = 0 THEN 0 ELSE CAST(b.April AS DECIMAL(10,4)) / c.April END
		,CASE WHEN c.May = 0 THEN 0 ELSE CAST(b.May AS DECIMAL(10,4)) / c.May END
		,CASE WHEN c.June = 0 THEN 0 ELSE CAST(b.June AS DECIMAL(10,4)) / c.June END
		,CASE WHEN c.July = 0 THEN 0 ELSE CAST(b.July AS DECIMAL(10,4)) / c.July END
		,CASE WHEN c.August = 0 THEN 0 ELSE CAST(b.August AS DECIMAL(10,4)) / c.August END
		,CASE WHEN c.September = 0 THEN 0 ELSE CAST(b.September AS DECIMAL(10,4)) / c.September END
		,CASE WHEN c.October = 0 THEN 0 ELSE CAST(b.October AS DECIMAL(10,4)) / c.October END
		,CASE WHEN c.November = 0 THEN 0 ELSE CAST(b.November AS DECIMAL(10,4)) / c.November END
		,CASE WHEN c.December = 0 THEN 0 ELSE CAST(b.December AS DECIMAL(10,4)) / c.December END
	FROM EBAAReportWarehouse b, EBAAReportWarehouse c
	WHERE b.Sort = '02.D' AND b.ReportYear = @reportYear
	AND c.Sort = '02.A' AND c.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'CalculationB'
		,'03.A.11'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0) + ISNULL(MAX(f.January), 0) + ISNULL(MAX(g.January), 0) + ISNULL(MAX(h.January), 0) + ISNULL(MAX(i.January), 0) + ISNULL(MAX(j.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0) + ISNULL(MAX(f.February), 0) + ISNULL(MAX(g.February), 0) + ISNULL(MAX(h.February), 0) + ISNULL(MAX(i.February), 0) + ISNULL(MAX(j.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) + ISNULL(MAX(e.March), 0) + ISNULL(MAX(f.March), 0) + ISNULL(MAX(g.March), 0) + ISNULL(MAX(h.March), 0) + ISNULL(MAX(i.March), 0) + ISNULL(MAX(j.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) + ISNULL(MAX(f.April), 0) + ISNULL(MAX(g.April), 0) + ISNULL(MAX(h.April), 0) + ISNULL(MAX(i.April), 0) + ISNULL(MAX(j.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0) + ISNULL(MAX(f.May), 0) + ISNULL(MAX(g.May), 0) + ISNULL(MAX(h.May), 0) + ISNULL(MAX(i.May), 0) + ISNULL(MAX(j.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0) + ISNULL(MAX(f.June), 0) + ISNULL(MAX(g.June), 0) + ISNULL(MAX(h.June), 0) + ISNULL(MAX(i.June), 0) + ISNULL(MAX(j.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0) + ISNULL(MAX(f.July), 0) + ISNULL(MAX(g.July), 0) + ISNULL(MAX(h.July), 0) + ISNULL(MAX(i.July), 0) + ISNULL(MAX(j.July), 0)
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0) + ISNULL(MAX(f.August), 0) + ISNULL(MAX(g.August), 0) + ISNULL(MAX(h.August), 0) + ISNULL(MAX(i.August), 0) + ISNULL(MAX(j.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0) + ISNULL(MAX(f.September), 0) + ISNULL(MAX(g.September), 0) + ISNULL(MAX(h.September), 0) + ISNULL(MAX(i.September), 0) + ISNULL(MAX(j.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) + ISNULL(MAX(f.October), 0) + ISNULL(MAX(g.October), 0) + ISNULL(MAX(h.October), 0) + ISNULL(MAX(i.October), 0) + ISNULL(MAX(j.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) + ISNULL(MAX(f.November), 0) + ISNULL(MAX(g.November), 0) + ISNULL(MAX(h.November), 0) + ISNULL(MAX(i.November), 0) + ISNULL(MAX(j.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0) + ISNULL(MAX(f.December), 0) + ISNULL(MAX(g.December), 0) + ISNULL(MAX(h.December), 0) + ISNULL(MAX(i.December), 0) + ISNULL(MAX(j.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '03.A.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '03.A.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '03.A.03'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '03.A.04'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
		ON base.Sort = e.Sort
		AND e.Sort = '03.A.05'
		AND e.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse f
		ON base.Sort = f.Sort
		AND f.Sort = '03.A.06'
		AND f.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse g
		ON base.Sort = g.Sort
		AND g.Sort = '03.A.07'
		AND g.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse h
		ON base.Sort = h.Sort
		AND h.Sort = '03.A.08'
		AND h.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse i
		ON base.Sort = i.Sort
		AND i.Sort = '03.A.09'
		AND i.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse j
		ON base.Sort = j.sort
		AND j.Sort = '03.A.10'
		AND j.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'ValidationB'
		,'03.A.12'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) - ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) - ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) - ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) - ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) - ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) - ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) - ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) - ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) - ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) - ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) - ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) - ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '02.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '03.A.11'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'CalculationC'
		,'03.B.03'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '03.B.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '03.B.02'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'ValidationC'
		,'03.B.04'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) - ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) - ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) - ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) - ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) - ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) - ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) - ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) - ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) - ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) - ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) - ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) - ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '02.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '03.B.03'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'CalculationD'
		,'03.C.07'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0) + ISNULL(MAX(f.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0) + ISNULL(MAX(f.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) + ISNULL(MAX(e.March), 0) + ISNULL(MAX(f.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) + ISNULL(MAX(f.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0) + ISNULL(MAX(f.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0) + ISNULL(MAX(f.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0) + ISNULL(MAX(f.July), 0)
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0) + ISNULL(MAX(f.August), 0) 
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0) + ISNULL(MAX(f.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) + ISNULL(MAX(f.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) + ISNULL(MAX(f.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0) + ISNULL(MAX(f.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '03.C.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '03.C.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '03.C.03'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '03.C.04'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
		ON base.Sort = e.Sort
		AND e.Sort = '03.C.05'
		AND e.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse f
		ON base.Sort = f.Sort
		AND f.Sort = '03.C.06'
		AND f.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'ValidationD'
		,'03.C.08'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) - ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) - ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) - ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) - ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) - ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) - ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) - ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) - ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) - ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) - ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) - ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) - ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '02.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '03.C.07'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'CalculationF'
		,'04.E.01.F'
		,@reportYear
		,CASE WHEN (ISNULL(MAX(c.January), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(c.June), 0) + 
		ISNULL(MAX(c.July), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(c.December), 0)) = 0
		THEN 0 
		ELSE 
		(
		(ISNULL(MAX(b.January), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(b.June), 0) + 
		ISNULL(MAX(b.July), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(b.December), 0))
		/
		(ISNULL(MAX(c.January), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(c.June), 0) + 
		ISNULL(MAX(c.July), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(c.December), 0))
		)
		END
		as YearCalculation	
		,CASE WHEN ISNULL(MAX(c.January), 0) = 0 THEN 0 ELSE CAST(MAX(b.January) AS DECIMAL(10,4)) / MAX(c.January) END
		,CASE WHEN ISNULL(MAX(c.February), 0) = 0 THEN 0 ELSE CAST(MAX(b.February) AS DECIMAL(10,4)) / MAX(c.February) END
		,CASE WHEN ISNULL(MAX(c.March), 0) = 0 THEN 0 ELSE CAST(MAX(b.March) AS DECIMAL(10,4)) / MAX(c.March) END
		,CASE WHEN ISNULL(MAX(c.April), 0) = 0 THEN 0 ELSE CAST(MAX(b.April) AS DECIMAL(10,4)) / MAX(c.April) END
		,CASE WHEN ISNULL(MAX(c.May), 0) = 0 THEN 0 ELSE CAST(MAX(b.May) AS DECIMAL(10,4)) / MAX(c.May) END
		,CASE WHEN ISNULL(MAX(c.June), 0) = 0 THEN 0 ELSE CAST(MAX(b.June) AS DECIMAL(10,4)) / MAX(c.June) END
		,CASE WHEN ISNULL(MAX(c.July), 0) = 0 THEN 0 ELSE CAST(MAX(b.July) AS DECIMAL(10,4)) / MAX(c.July) END
		,CASE WHEN ISNULL(MAX(c.August), 0) = 0 THEN 0 ELSE CAST(MAX(b.August) AS DECIMAL(10,4)) / MAX(c.August) END
		,CASE WHEN ISNULL(MAX(c.September), 0) = 0 THEN 0 ELSE CAST(MAX(b.September) AS DECIMAL(10,4)) / MAX(c.September) END
		,CASE WHEN ISNULL(MAX(c.October), 0) = 0 THEN 0 ELSE CAST(MAX(b.October) AS DECIMAL(10,4)) / MAX(c.October) END
		,CASE WHEN ISNULL(MAX(c.November), 0) = 0 THEN 0 ELSE CAST(MAX(b.November) AS DECIMAL(10,4)) / MAX(c.November) END
		,CASE WHEN ISNULL(MAX(c.December), 0) = 0 THEN 0 ELSE CAST(MAX(b.December) AS DECIMAL(10,4)) / MAX(c.December) END
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.E.01'
		AND b.ReportYear = @ReportYear
	LEFT JOIN EBAAReportWarehouse c
		ON base.Sort = c.Sort
		AND c.Sort = '04.E'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'CalculationG'
		,'04.E.02.G'
		,@reportYear
		,CASE WHEN (ISNULL(MAX(c.January), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(c.June), 0) + 
		ISNULL(MAX(c.July), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(c.December), 0)) = 0
		THEN 0 
		ELSE 
		(
		(ISNULL(MAX(b.January), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(b.June), 0) + 
		ISNULL(MAX(b.July), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(b.December), 0))
		/
		(ISNULL(MAX(c.January), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(c.June), 0) + 
		ISNULL(MAX(c.July), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(c.December), 0))
		)
		END
		as YearCalculation	
		,CASE WHEN ISNULL(MAX(c.January), 0) = 0 THEN 0 ELSE CAST(MAX(b.January) AS DECIMAL(10,4)) / MAX(c.January) END
		,CASE WHEN ISNULL(MAX(c.February), 0) = 0 THEN 0 ELSE CAST(MAX(b.February) AS DECIMAL(10,4)) / MAX(c.February) END
		,CASE WHEN ISNULL(MAX(c.March), 0) = 0 THEN 0 ELSE CAST(MAX(b.March) AS DECIMAL(10,4)) / MAX(c.March) END
		,CASE WHEN ISNULL(MAX(c.April), 0) = 0 THEN 0 ELSE CAST(MAX(b.April) AS DECIMAL(10,4)) / MAX(c.April) END
		,CASE WHEN ISNULL(MAX(c.May), 0) = 0 THEN 0 ELSE CAST(MAX(b.May) AS DECIMAL(10,4)) / MAX(c.May) END
		,CASE WHEN ISNULL(MAX(c.June), 0) = 0 THEN 0 ELSE CAST(MAX(b.June) AS DECIMAL(10,4)) / MAX(c.June) END
		,CASE WHEN ISNULL(MAX(c.July), 0) = 0 THEN 0 ELSE CAST(MAX(b.July) AS DECIMAL(10,4)) / MAX(c.July) END
		,CASE WHEN ISNULL(MAX(c.August), 0) = 0 THEN 0 ELSE CAST(MAX(b.August) AS DECIMAL(10,4)) / MAX(c.August) END
		,CASE WHEN ISNULL(MAX(c.September), 0) = 0 THEN 0 ELSE CAST(MAX(b.September) AS DECIMAL(10,4)) / MAX(c.September) END
		,CASE WHEN ISNULL(MAX(c.October), 0) = 0 THEN 0 ELSE CAST(MAX(b.October) AS DECIMAL(10,4)) / MAX(c.October) END
		,CASE WHEN ISNULL(MAX(c.November), 0) = 0 THEN 0 ELSE CAST(MAX(b.November) AS DECIMAL(10,4)) / MAX(c.November) END
		,CASE WHEN ISNULL(MAX(c.December), 0) = 0 THEN 0 ELSE CAST(MAX(b.December) AS DECIMAL(10,4)) / MAX(c.December) END
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.E.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON base.Sort = c.Sort
		AND c.Sort = '04.E'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'CalculationH'
		,'04.E.03.H'
		,@reportYear
		,CASE WHEN (ISNULL(MAX(c.January), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(c.June), 0) + 
		ISNULL(MAX(c.July), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(c.December), 0)) = 0
		THEN 0 
		ELSE 
		(
		(ISNULL(MAX(b.January), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(b.June), 0) + 
		ISNULL(MAX(b.July), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(b.December), 0))
		/
		(ISNULL(MAX(c.January), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(c.June), 0) + 
		ISNULL(MAX(c.July), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(c.December), 0))
		)
		END
		as YearCalculation	
		,CASE WHEN ISNULL(MAX(c.January), 0) = 0 THEN 0 ELSE CAST(MAX(b.January) AS DECIMAL(10,4)) / MAX(c.January) END
		,CASE WHEN ISNULL(MAX(c.February), 0) = 0 THEN 0 ELSE CAST(MAX(b.February) AS DECIMAL(10,4)) / MAX(c.February) END
		,CASE WHEN ISNULL(MAX(c.March), 0) = 0 THEN 0 ELSE CAST(MAX(b.March) AS DECIMAL(10,4)) / MAX(c.March) END
		,CASE WHEN ISNULL(MAX(c.April), 0) = 0 THEN 0 ELSE CAST(MAX(b.April) AS DECIMAL(10,4)) / MAX(c.April) END
		,CASE WHEN ISNULL(MAX(c.May), 0) = 0 THEN 0 ELSE CAST(MAX(b.May) AS DECIMAL(10,4)) / MAX(c.May) END
		,CASE WHEN ISNULL(MAX(c.June), 0) = 0 THEN 0 ELSE CAST(MAX(b.June) AS DECIMAL(10,4)) / MAX(c.June) END
		,CASE WHEN ISNULL(MAX(c.July), 0) = 0 THEN 0 ELSE CAST(MAX(b.July) AS DECIMAL(10,4)) / MAX(c.July) END
		,CASE WHEN ISNULL(MAX(c.August), 0) = 0 THEN 0 ELSE CAST(MAX(b.August) AS DECIMAL(10,4)) / MAX(c.August) END
		,CASE WHEN ISNULL(MAX(c.September), 0) = 0 THEN 0 ELSE CAST(MAX(b.September) AS DECIMAL(10,4)) / MAX(c.September) END
		,CASE WHEN ISNULL(MAX(c.October), 0) = 0 THEN 0 ELSE CAST(MAX(b.October) AS DECIMAL(10,4)) / MAX(c.October) END
		,CASE WHEN ISNULL(MAX(c.November), 0) = 0 THEN 0 ELSE CAST(MAX(b.November) AS DECIMAL(10,4)) / MAX(c.November) END
		,CASE WHEN ISNULL(MAX(c.December), 0) = 0 THEN 0 ELSE CAST(MAX(b.December) AS DECIMAL(10,4)) / MAX(c.December) END
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.E.03'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON base.Sort = c.Sort
		AND c.Sort = '04.E'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'CalculationI'
		,'04.E.04.I'
		,@reportYear
		,CASE WHEN (ISNULL(MAX(c.January), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(c.June), 0) + 
		ISNULL(MAX(c.July), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(c.December), 0)) = 0
		THEN 0 
		ELSE 
		(
		(ISNULL(MAX(b.January), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(b.June), 0) + 
		ISNULL(MAX(b.July), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(b.December), 0))
		/
		(ISNULL(MAX(c.January), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(c.June), 0) + 
		ISNULL(MAX(c.July), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(c.December), 0))
		)
		END
		as YearCalculation	
		,CASE WHEN ISNULL(MAX(c.January), 0) = 0 THEN 0 ELSE CAST(MAX(b.January) AS DECIMAL(10,4)) / MAX(c.January) END
		,CASE WHEN ISNULL(MAX(c.February), 0) = 0 THEN 0 ELSE CAST(MAX(b.February) AS DECIMAL(10,4)) / MAX(c.February) END
		,CASE WHEN ISNULL(MAX(c.March), 0) = 0 THEN 0 ELSE CAST(MAX(b.March) AS DECIMAL(10,4)) / MAX(c.March) END
		,CASE WHEN ISNULL(MAX(c.April), 0) = 0 THEN 0 ELSE CAST(MAX(b.April) AS DECIMAL(10,4)) / MAX(c.April) END
		,CASE WHEN ISNULL(MAX(c.May), 0) = 0 THEN 0 ELSE CAST(MAX(b.May) AS DECIMAL(10,4)) / MAX(c.May) END
		,CASE WHEN ISNULL(MAX(c.June), 0) = 0 THEN 0 ELSE CAST(MAX(b.June) AS DECIMAL(10,4)) / MAX(c.June) END
		,CASE WHEN ISNULL(MAX(c.July), 0) = 0 THEN 0 ELSE CAST(MAX(b.July) AS DECIMAL(10,4)) / MAX(c.July) END
		,CASE WHEN ISNULL(MAX(c.August), 0) = 0 THEN 0 ELSE CAST(MAX(b.August) AS DECIMAL(10,4)) / MAX(c.August) END
		,CASE WHEN ISNULL(MAX(c.September), 0) = 0 THEN 0 ELSE CAST(MAX(b.September) AS DECIMAL(10,4)) / MAX(c.September) END
		,CASE WHEN ISNULL(MAX(c.October), 0) = 0 THEN 0 ELSE CAST(MAX(b.October) AS DECIMAL(10,4)) / MAX(c.October) END
		,CASE WHEN ISNULL(MAX(c.November), 0) = 0 THEN 0 ELSE CAST(MAX(b.November) AS DECIMAL(10,4)) / MAX(c.November) END
		,CASE WHEN ISNULL(MAX(c.December), 0) = 0 THEN 0 ELSE CAST(MAX(b.December) AS DECIMAL(10,4)) / MAX(c.December) END
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.E.04'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON base.Sort = c.Sort
		AND c.Sort = '04.E'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'CalculationJ'
		,'04.E.05.J'
		,@reportYear
		,CASE WHEN (ISNULL(MAX(c.January), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(c.June), 0) + 
		ISNULL(MAX(c.July), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(c.December), 0)) = 0
		THEN 0 
		ELSE 
		(
		(ISNULL(MAX(b.January), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(b.June), 0) + 
		ISNULL(MAX(b.July), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(b.December), 0))
		/
		(ISNULL(MAX(c.January), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(c.June), 0) + 
		ISNULL(MAX(c.July), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(c.December), 0))
		)
		END
		as YearCalculation	
		,CASE WHEN ISNULL(MAX(c.January), 0) = 0 THEN 0 ELSE CAST(MAX(b.January) AS DECIMAL(10,4)) / MAX(c.January) END
		,CASE WHEN ISNULL(MAX(c.February), 0) = 0 THEN 0 ELSE CAST(MAX(b.February) AS DECIMAL(10,4)) / MAX(c.February) END
		,CASE WHEN ISNULL(MAX(c.March), 0) = 0 THEN 0 ELSE CAST(MAX(b.March) AS DECIMAL(10,4)) / MAX(c.March) END
		,CASE WHEN ISNULL(MAX(c.April), 0) = 0 THEN 0 ELSE CAST(MAX(b.April) AS DECIMAL(10,4)) / MAX(c.April) END
		,CASE WHEN ISNULL(MAX(c.May), 0) = 0 THEN 0 ELSE CAST(MAX(b.May) AS DECIMAL(10,4)) / MAX(c.May) END
		,CASE WHEN ISNULL(MAX(c.June), 0) = 0 THEN 0 ELSE CAST(MAX(b.June) AS DECIMAL(10,4)) / MAX(c.June) END
		,CASE WHEN ISNULL(MAX(c.July), 0) = 0 THEN 0 ELSE CAST(MAX(b.July) AS DECIMAL(10,4)) / MAX(c.July) END
		,CASE WHEN ISNULL(MAX(c.August), 0) = 0 THEN 0 ELSE CAST(MAX(b.August) AS DECIMAL(10,4)) / MAX(c.August) END
		,CASE WHEN ISNULL(MAX(c.September), 0) = 0 THEN 0 ELSE CAST(MAX(b.September) AS DECIMAL(10,4)) / MAX(c.September) END
		,CASE WHEN ISNULL(MAX(c.October), 0) = 0 THEN 0 ELSE CAST(MAX(b.October) AS DECIMAL(10,4)) / MAX(c.October) END
		,CASE WHEN ISNULL(MAX(c.November), 0) = 0 THEN 0 ELSE CAST(MAX(b.November) AS DECIMAL(10,4)) / MAX(c.November) END
		,CASE WHEN ISNULL(MAX(c.December), 0) = 0 THEN 0 ELSE CAST(MAX(b.December) AS DECIMAL(10,4)) / MAX(c.December) END
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.E.05'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON base.Sort = c.Sort
		AND c.Sort = '04.E'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'PK'
		,'05.C.01'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.C.01.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.C.01.B'
		AND b.reportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'EK'
		,'05.C.02'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.C.02.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.C.02.B'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'ALK'
		,'05.C.03'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0)  + ISNULL(MAX(c.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0)+ ISNULL(MAX(c.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0)
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0)+ ISNULL(MAX(c.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0)+ ISNULL(MAX(c.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.C.03.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.C.03.B'
		AND b.ReportYear = @reportYear
	--DE9412
	LEFT JOIN EBAAReportWarehouse c 
		ON base.Sort = c.Sort
		AND c.Sort = '05.C.03.C'
		AND c.ReportYear = @reportYear
	--DE9412
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'IntermediateUS'
		,'05.C'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0) + ISNULL(MAX(f.January), 0) + ISNULL(MAX(g.January), 0) +  ISNULL(MAX(h.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0) + ISNULL(MAX(f.February), 0) + ISNULL(MAX(g.February), 0)  + ISNULL(MAX(h.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0)+ ISNULL(MAX(e.March), 0) + ISNULL(MAX(f.March), 0) + ISNULL(MAX(g.March), 0)  + ISNULL(MAX(h.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) + ISNULL(MAX(f.April), 0) + ISNULL(MAX(g.April), 0) + ISNULL(MAX(h.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0) + ISNULL(MAX(f.May), 0) + ISNULL(MAX(g.May), 0) + ISNULL(MAX(h.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0) + ISNULL(MAX(f.June), 0) + ISNULL(MAX(g.June), 0) + ISNULL(MAX(h.June), 0) 
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0) + ISNULL(MAX(f.July), 0) + ISNULL(MAX(g.July), 0) + ISNULL(MAX(h.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0) + ISNULL(MAX(f.August), 0) + ISNULL(MAX(g.August), 0) + ISNULL(MAX(h.August), 0) 
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0) + ISNULL(MAX(f.September), 0) + ISNULL(MAX(g.September), 0) + ISNULL(MAX(h.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) + ISNULL(MAX(f.October), 0) + ISNULL(MAX(g.October), 0) + ISNULL(MAX(h.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) + ISNULL(MAX(f.November), 0) + ISNULL(MAX(g.November), 0) + ISNULL(MAX(h.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0) + ISNULL(MAX(f.December), 0) + ISNULL(MAX(g.December), 0) + ISNULL(MAX(h.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.C.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.C.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '05.C.03'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '05.C.04'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
			ON base.Sort = e.Sort
			AND e.Sort = '05.C.05'
			AND e.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse f
			ON base.Sort = f.Sort
			AND f.Sort = '05.C.06'
			AND f.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse g
			ON base.Sort = g.Sort
			AND g.Sort = '05.C.07'
			AND g.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse h
		ON base.Sort = h.Sort
		AND h.Sort = '05.C.08'	
		AND h.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'PK'
		,'05.D.01'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.D.01.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.D.01.B'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'EK'
		,'05.D.02'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.D.02.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.D.02.B'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'ALK'
		,'05.D.03'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0)  + ISNULL(MAX(c.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0)+ ISNULL(MAX(c.June), 0) 
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0)+ ISNULL(MAX(c.August), 0) 
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0)+ ISNULL(MAX(c.September), 0) 
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.D.03.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.D.03.B'
		AND b.ReportYear = @reportYear
	--DE9412
	LEFT JOIN EBAAReportWarehouse c 
		ON base.Sort = c.Sort
		AND c.Sort = '05.D.03.C'
		AND c.ReportYear = @reportYear
	--DE9412
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'IntermediateInternational'
		,'05.D'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0) + ISNULL(MAX(f.January), 0) + ISNULL(MAX(g.January), 0) +  ISNULL(MAX(h.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0) + ISNULL(MAX(f.February), 0) + ISNULL(MAX(g.February), 0)  + ISNULL(MAX(h.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0)+ ISNULL(MAX(e.March), 0) + ISNULL(MAX(f.March), 0) + ISNULL(MAX(g.March), 0)  + ISNULL(MAX(h.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) + ISNULL(MAX(f.April), 0) + ISNULL(MAX(g.April), 0) + ISNULL(MAX(h.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0) + ISNULL(MAX(f.May), 0) + ISNULL(MAX(g.May), 0) + ISNULL(MAX(h.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0) + ISNULL(MAX(f.June), 0) + ISNULL(MAX(g.June), 0) + ISNULL(MAX(h.June), 0) 
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0) + ISNULL(MAX(f.July), 0) + ISNULL(MAX(g.July), 0) + ISNULL(MAX(h.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0) + ISNULL(MAX(f.August), 0) + ISNULL(MAX(g.August), 0) + ISNULL(MAX(h.August), 0) 
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0) + ISNULL(MAX(f.September), 0) + ISNULL(MAX(g.September), 0) + ISNULL(MAX(h.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) + ISNULL(MAX(f.October), 0) + ISNULL(MAX(g.October), 0) + ISNULL(MAX(h.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) + ISNULL(MAX(f.November), 0) + ISNULL(MAX(g.November), 0) + ISNULL(MAX(h.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0) + ISNULL(MAX(f.December), 0) + ISNULL(MAX(g.December), 0) + ISNULL(MAX(h.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.D.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.D.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '05.D.03'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '05.D.04'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
			ON base.Sort = e.Sort
			AND e.Sort = '05.D.05'
			AND e.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse f
			ON base.Sort = f.Sort
			AND f.Sort = '05.D.06'
			AND f.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse g
			ON base.Sort = g.Sort
			AND g.Sort = '05.D.07'
			AND g.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse h
		ON base.Sort = h.Sort
		AND h.Sort = '05.D.08'	
		AND h.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'CalculationK'
		,'05.K'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0) + ISNULL(MAX(f.January), 0) + ISNULL(MAX(g.January), 0) + ISNULL(MAX(h.January), 0) + ISNULL(MAX(i.January), 0) + ISNULL(MAX(j.January), 0) + ISNULL(MAX(k.January), 0) + ISNULL(MAX(l.January), 0) + ISNULL(MAX(m.January), 0) + ISNULL(MAX(n.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0) + ISNULL(MAX(f.February), 0) + ISNULL(MAX(g.February), 0) + ISNULL(MAX(h.February), 0) + ISNULL(MAX(i.February), 0) + ISNULL(MAX(j.February), 0) + ISNULL(MAX(k.February), 0) + ISNULL(MAX(l.February), 0)+ ISNULL(MAX(m.February), 0) + ISNULL(MAX(n.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) + ISNULL(MAX(e.March), 0) + ISNULL(MAX(f.March), 0) + ISNULL(MAX(g.March), 0) + ISNULL(MAX(h.March), 0) + ISNULL(MAX(i.March), 0) + ISNULL(MAX(j.March), 0) + ISNULL(MAX(k.March), 0) + ISNULL(MAX(l.March), 0)+ ISNULL(MAX(m.March), 0) + ISNULL(MAX(n.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) + ISNULL(MAX(f.April), 0) + ISNULL(MAX(g.April), 0) + ISNULL(MAX(h.April), 0) + ISNULL(MAX(i.April), 0) + ISNULL(MAX(j.April), 0) + ISNULL(MAX(k.April), 0) + ISNULL(MAX(l.April), 0) + ISNULL(MAX(m.April), 0) + ISNULL(MAX(n.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0) + ISNULL(MAX(f.May), 0) + ISNULL(MAX(g.May), 0) + ISNULL(MAX(h.May), 0) + ISNULL(MAX(i.May), 0) + ISNULL(MAX(j.May), 0) + ISNULL(MAX(k.May), 0) + ISNULL(MAX(l.May), 0) + ISNULL(MAX(m.May), 0) + ISNULL(MAX(n.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0) + ISNULL(MAX(f.June), 0) + ISNULL(MAX(g.June), 0) + ISNULL(MAX(h.June), 0) + ISNULL(MAX(i.June), 0) + ISNULL(MAX(j.June), 0) + ISNULL(MAX(k.June), 0) + ISNULL(MAX(l.June), 0) + ISNULL(MAX(m.June), 0) + ISNULL(MAX(n.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0) + ISNULL(MAX(f.July), 0) + ISNULL(MAX(g.July), 0) + ISNULL(MAX(h.July), 0) + ISNULL(MAX(i.July), 0) + ISNULL(MAX(j.July), 0) + ISNULL(MAX(k.July), 0) + ISNULL(MAX(l.July), 0)+ ISNULL(MAX(m.July), 0) + ISNULL(MAX(n.July), 0)
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0) + ISNULL(MAX(f.August), 0) + ISNULL(MAX(g.August), 0) + ISNULL(MAX(h.August), 0) + ISNULL(MAX(i.August), 0) + ISNULL(MAX(j.August), 0) + ISNULL(MAX(k.August), 0) + ISNULL(MAX(l.August), 0)+ ISNULL(MAX(m.August), 0) + ISNULL(MAX(n.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0) + ISNULL(MAX(f.September), 0) + ISNULL(MAX(g.September), 0) + ISNULL(MAX(h.September), 0) + ISNULL(MAX(i.September), 0) + ISNULL(MAX(j.September), 0) + ISNULL(MAX(k.September), 0) + ISNULL(MAX(l.September), 0) + ISNULL(MAX(m.September), 0) + ISNULL(MAX(n.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) + ISNULL(MAX(f.October), 0) + ISNULL(MAX(g.October), 0) + ISNULL(MAX(h.October), 0) + ISNULL(MAX(i.October), 0) + ISNULL(MAX(j.October), 0) + ISNULL(MAX(k.October), 0) + ISNULL(MAX(l.October), 0) + ISNULL(MAX(m.October), 0) + ISNULL(MAX(n.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) + ISNULL(MAX(f.November), 0) + ISNULL(MAX(g.November), 0) + ISNULL(MAX(h.November), 0) + ISNULL(MAX(i.November), 0) + ISNULL(MAX(j.November), 0) + ISNULL(MAX(k.November), 0) + ISNULL(MAX(l.November), 0) + ISNULL(MAX(m.November), 0) + ISNULL(MAX(n.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0) + ISNULL(MAX(f.December), 0) + ISNULL(MAX(g.December), 0) + ISNULL(MAX(h.December), 0) + ISNULL(MAX(i.December), 0) + ISNULL(MAX(j.December), 0) + ISNULL(MAX(k.December), 0) + ISNULL(MAX(l.December), 0)+ ISNULL(MAX(m.December), 0) + ISNULL(MAX(n.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.C.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.C.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '05.C.03'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '05.C.05'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
		ON base.Sort = e.Sort
		AND e.Sort = '05.C.07'
		AND e.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse f
		ON base.Sort = f.Sort
		AND f.Sort = '05.C.08'
		AND f.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse g
		ON base.Sort = g.Sort
		AND g.Sort = '05.D.01'
		AND g.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse h
		ON base.Sort = h.Sort
		AND h.Sort = '05.D.02'
		AND h.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse i
		ON base.Sort = i.Sort
		AND i.Sort = '05.D.03'
		AND i.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse j
		ON base.Sort = j.sort
		AND j.Sort = '05.D.05'
		AND j.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse k
		ON base.Sort = k.sort
		AND k.Sort = '05.D.07'
		AND k.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse l
		ON base.Sort = l.sort
		AND l.Sort = '05.D.08'
		AND l.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse m
		ON base.Sort = m.Sort
		AND m.Sort = '05.C.04'
		AND m.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse n
		ON base.Sort = n.Sort
		AND n.Sort = '05.D.04'
		AND n.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT DISTINCT
		 'CalculationL'
		,'05.L'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) - ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) - ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) - ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) - ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) - ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) - ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) 
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) - ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) - ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) - ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) - ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) - ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) - ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.C'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.D'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '05.B'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '05.A'
		AND d.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'LongTermDistributed'
		,'06.B'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0)  
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '06.B.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '06.B.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON base.Sort = c.Sort
		AND c.Sort = '06.B.03'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'CalculationM'
		,'06.C.01'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) 
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) 
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.L'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '06.A'
		AND b.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'ValidationM' --2B-4B-4D - (Calculation M)
		,'06.C.02'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) - ISNULL(MAX(b.January), 0) - ISNULL(MAX(d.January), 0) - ISNULL(MAX(c.January), 0)  
		,ISNULL(MAX(a.February), 0) - ISNULL(MAX(b.February), 0) - ISNULL(MAX(d.February), 0) - ISNULL(MAX(c.February), 0) 
		,ISNULL(MAX(a.March), 0) - ISNULL(MAX(b.March), 0) - ISNULL(MAX(d.March), 0) - ISNULL(MAX(c.March), 0) 
		,ISNULL(MAX(a.April), 0) - ISNULL(MAX(b.April), 0) - ISNULL(MAX(d.April), 0) - ISNULL(MAX(c.April), 0) 
		,ISNULL(MAX(a.May), 0) - ISNULL(MAX(b.May), 0) - ISNULL(MAX(d.May), 0) - ISNULL(MAX(c.May), 0) 
		,ISNULL(MAX(a.June), 0) - ISNULL(MAX(b.June), 0) - ISNULL(MAX(d.June), 0) - ISNULL(MAX(c.June), 0)
		,ISNULL(MAX(a.July), 0) - ISNULL(MAX(b.July), 0) - ISNULL(MAX(d.July), 0) - ISNULL(MAX(c.July), 0) 
		,ISNULL(MAX(a.August), 0) - ISNULL(MAX(b.August), 0) - ISNULL(MAX(d.August), 0) - ISNULL(MAX(c.August), 0)
		,ISNULL(MAX(a.September), 0) - ISNULL(MAX(b.September), 0) - ISNULL(MAX(d.September), 0) - ISNULL(MAX(c.September), 0)
		,ISNULL(MAX(a.October), 0) - ISNULL(MAX(b.October), 0) - ISNULL(MAX(d.October), 0) - ISNULL(MAX(c.October), 0) 
		,ISNULL(MAX(a.November), 0) - ISNULL(MAX(b.November), 0) - ISNULL(MAX(d.November), 0) - ISNULL(MAX(c.November), 0) 
		,ISNULL(MAX(a.December), 0) - ISNULL(MAX(b.December), 0) - ISNULL(MAX(d.December), 0) - ISNULL(MAX(c.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '02.B'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.B'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON base.Sort = c.Sort
		AND c.Sort = '06.C.01'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '04.D'
		AND d.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'ScleraDistributed'
		,'06.E'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0)  
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '06.E.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '06.E.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON base.Sort = c.Sort
		AND c.Sort = '06.E.03'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'CalculationN'
		,'10.Z.01'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0) + ISNULL(MAX(f.January), 0) + ISNULL(MAX(g.January), 0) + ISNULL(MAX(h.January), 0) + ISNULL(MAX(i.January), 0) + ISNULL(MAX(j.January), 0) + ISNULL(MAX(k.January), 0) + ISNULL(MAX(l.January), 0) + ISNULL(MAX(m.January), 0) + ISNULL(MAX(z.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0) + ISNULL(MAX(f.February), 0) + ISNULL(MAX(g.February), 0) + ISNULL(MAX(h.February), 0) + ISNULL(MAX(i.February), 0) + ISNULL(MAX(j.February), 0) + ISNULL(MAX(k.February), 0) + ISNULL(MAX(l.February), 0) + ISNULL(MAX(m.February), 0) + ISNULL(MAX(z.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) + ISNULL(MAX(e.March), 0) + ISNULL(MAX(f.March), 0) + ISNULL(MAX(g.March), 0) + ISNULL(MAX(h.March), 0) + ISNULL(MAX(i.March), 0) + ISNULL(MAX(j.March), 0) + ISNULL(MAX(k.March), 0) + ISNULL(MAX(l.March), 0) + ISNULL(MAX(m.March), 0) + ISNULL(MAX(z.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) + ISNULL(MAX(f.April), 0) + ISNULL(MAX(g.April), 0) + ISNULL(MAX(h.April), 0) + ISNULL(MAX(i.April), 0) + ISNULL(MAX(j.April), 0) + ISNULL(MAX(k.April), 0) + ISNULL(MAX(l.April), 0) + ISNULL(MAX(m.April), 0) + ISNULL(MAX(z.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0) + ISNULL(MAX(f.May), 0) + ISNULL(MAX(g.May), 0) + ISNULL(MAX(h.May), 0) + ISNULL(MAX(i.May), 0) + ISNULL(MAX(j.May), 0) + ISNULL(MAX(k.May), 0) + ISNULL(MAX(l.May), 0) + ISNULL(MAX(m.May), 0) + ISNULL(MAX(z.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0) + ISNULL(MAX(f.June), 0) + ISNULL(MAX(g.June), 0) + ISNULL(MAX(h.June), 0) + ISNULL(MAX(i.June), 0) + ISNULL(MAX(j.June), 0) + ISNULL(MAX(k.June), 0) + ISNULL(MAX(l.June), 0) + ISNULL(MAX(m.June), 0) + ISNULL(MAX(z.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0) + ISNULL(MAX(f.July), 0) + ISNULL(MAX(g.July), 0) + ISNULL(MAX(h.July), 0) + ISNULL(MAX(i.July), 0) + ISNULL(MAX(j.July), 0) + ISNULL(MAX(k.July), 0) + ISNULL(MAX(l.July), 0) + ISNULL(MAX(m.July), 0) + ISNULL(MAX(z.July), 0)
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0) + ISNULL(MAX(f.August), 0) + ISNULL(MAX(g.August), 0) + ISNULL(MAX(h.August), 0) + ISNULL(MAX(i.August), 0) + ISNULL(MAX(j.August), 0) + ISNULL(MAX(k.August), 0) + ISNULL(MAX(l.August), 0) + ISNULL(MAX(m.August), 0) + ISNULL(MAX(z.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0) + ISNULL(MAX(f.September), 0) + ISNULL(MAX(g.September), 0) + ISNULL(MAX(h.September), 0) + ISNULL(MAX(i.September), 0) + ISNULL(MAX(j.September), 0) + ISNULL(MAX(k.September), 0) + ISNULL(MAX(l.September), 0) + ISNULL(MAX(m.September), 0) + ISNULL(MAX(z.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) + ISNULL(MAX(f.October), 0) + ISNULL(MAX(g.October), 0) + ISNULL(MAX(h.October), 0) + ISNULL(MAX(i.October), 0) + ISNULL(MAX(j.October), 0) + ISNULL(MAX(k.October), 0) + ISNULL(MAX(l.October), 0) + ISNULL(MAX(m.October), 0) + ISNULL(MAX(z.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) + ISNULL(MAX(f.November), 0) + ISNULL(MAX(g.November), 0) + ISNULL(MAX(h.November), 0) + ISNULL(MAX(i.November), 0) + ISNULL(MAX(j.November), 0) + ISNULL(MAX(k.November), 0) + ISNULL(MAX(l.November), 0) + ISNULL(MAX(m.November), 0) + ISNULL(MAX(z.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0) + ISNULL(MAX(f.December), 0) + ISNULL(MAX(g.December), 0) + ISNULL(MAX(h.December), 0) + ISNULL(MAX(i.December), 0) + ISNULL(MAX(j.December), 0) + ISNULL(MAX(k.December), 0) + ISNULL(MAX(l.December), 0) + ISNULL(MAX(m.December), 0) + ISNULL(MAX(z.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '10.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '10.B'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '10.C'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '10.D'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
		ON base.Sort = e.Sort
		AND e.Sort = '10.E'
		AND e.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse f
		ON base.Sort = f.Sort
		AND f.Sort = '10.F'
		AND f.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse g
		ON base.Sort = g.Sort
		AND g.Sort = '10.G'
		AND g.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse h
		ON base.Sort = h.Sort
		AND h.Sort = '10.H'
		AND h.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse i
		ON base.Sort = i.Sort
		AND i.Sort = '10.I'
		AND i.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse j
		ON base.Sort = j.sort
		AND j.Sort = '10.J'
		AND j.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse k
		ON base.Sort = k.sort
		AND k.Sort = '10.K'
		AND k.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse l
		ON base.Sort = l.sort
		AND l.Sort = '10.L'
		AND l.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse m
		ON base.Sort = m.sort
		AND m.Sort = '10.M'
		AND m.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse z
		ON base.Sort = z.sort
		AND z.Sort = '10.Z'
		AND z.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'ValidationN'
		,'10.Z.02'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) - ISNULL(MAX(c.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) - ISNULL(MAX(c.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) - ISNULL(MAX(c.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) - ISNULL(MAX(c.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) - ISNULL(MAX(c.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) - ISNULL(MAX(c.June), 0) 
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) - ISNULL(MAX(c.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) - ISNULL(MAX(c.August), 0) 
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) - ISNULL(MAX(c.September), 0) 
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) - ISNULL(MAX(c.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) - ISNULL(MAX(c.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) - ISNULL(MAX(c.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.C.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.D.01'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '10.Z.01'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'CalculationO'
		,'11.Z.01'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0) + ISNULL(MAX(f.January), 0) + ISNULL(MAX(g.January), 0) + ISNULL(MAX(h.January), 0) + ISNULL(MAX(i.January), 0) + ISNULL(MAX(j.January), 0) + ISNULL(MAX(k.January), 0) + ISNULL(MAX(l.January), 0) + ISNULL(MAX(m.January), 0) + ISNULL(MAX(z.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0) + ISNULL(MAX(f.February), 0) + ISNULL(MAX(g.February), 0) + ISNULL(MAX(h.February), 0) + ISNULL(MAX(i.February), 0) + ISNULL(MAX(j.February), 0) + ISNULL(MAX(k.February), 0) + ISNULL(MAX(l.February), 0) + ISNULL(MAX(m.February), 0) + ISNULL(MAX(z.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) + ISNULL(MAX(e.March), 0) + ISNULL(MAX(f.March), 0) + ISNULL(MAX(g.March), 0) + ISNULL(MAX(h.March), 0) + ISNULL(MAX(i.March), 0) + ISNULL(MAX(j.March), 0) + ISNULL(MAX(k.March), 0) + ISNULL(MAX(l.March), 0) + ISNULL(MAX(m.March), 0) + ISNULL(MAX(z.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) + ISNULL(MAX(f.April), 0) + ISNULL(MAX(g.April), 0) + ISNULL(MAX(h.April), 0) + ISNULL(MAX(i.April), 0) + ISNULL(MAX(j.April), 0) + ISNULL(MAX(k.April), 0) + ISNULL(MAX(l.April), 0) + ISNULL(MAX(m.April), 0) + ISNULL(MAX(z.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0) + ISNULL(MAX(f.May), 0) + ISNULL(MAX(g.May), 0) + ISNULL(MAX(h.May), 0) + ISNULL(MAX(i.May), 0) + ISNULL(MAX(j.May), 0) + ISNULL(MAX(k.May), 0) + ISNULL(MAX(l.May), 0) + ISNULL(MAX(m.May), 0) + ISNULL(MAX(z.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0) + ISNULL(MAX(f.June), 0) + ISNULL(MAX(g.June), 0) + ISNULL(MAX(h.June), 0) + ISNULL(MAX(i.June), 0) + ISNULL(MAX(j.June), 0) + ISNULL(MAX(k.June), 0) + ISNULL(MAX(l.June), 0) + ISNULL(MAX(m.June), 0) + ISNULL(MAX(z.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0) + ISNULL(MAX(f.July), 0) + ISNULL(MAX(g.July), 0) + ISNULL(MAX(h.July), 0) + ISNULL(MAX(i.July), 0) + ISNULL(MAX(j.July), 0) + ISNULL(MAX(k.July), 0) + ISNULL(MAX(l.July), 0) + ISNULL(MAX(m.July), 0) + ISNULL(MAX(z.July), 0)
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0) + ISNULL(MAX(f.August), 0) + ISNULL(MAX(g.August), 0) + ISNULL(MAX(h.August), 0) + ISNULL(MAX(i.August), 0) + ISNULL(MAX(j.August), 0) + ISNULL(MAX(k.August), 0) + ISNULL(MAX(l.August), 0) + ISNULL(MAX(m.August), 0) + ISNULL(MAX(z.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0) + ISNULL(MAX(f.September), 0) + ISNULL(MAX(g.September), 0) + ISNULL(MAX(h.September), 0) + ISNULL(MAX(i.September), 0) + ISNULL(MAX(j.September), 0) + ISNULL(MAX(k.September), 0) + ISNULL(MAX(l.September), 0) + ISNULL(MAX(m.September), 0) + ISNULL(MAX(z.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) + ISNULL(MAX(f.October), 0) + ISNULL(MAX(g.October), 0) + ISNULL(MAX(h.October), 0) + ISNULL(MAX(i.October), 0) + ISNULL(MAX(j.October), 0) + ISNULL(MAX(k.October), 0) + ISNULL(MAX(l.October), 0) + ISNULL(MAX(m.October), 0) + ISNULL(MAX(z.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) + ISNULL(MAX(f.November), 0) + ISNULL(MAX(g.November), 0) + ISNULL(MAX(h.November), 0) + ISNULL(MAX(i.November), 0) + ISNULL(MAX(j.November), 0) + ISNULL(MAX(k.November), 0) + ISNULL(MAX(l.November), 0) + ISNULL(MAX(m.November), 0) + ISNULL(MAX(z.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0) + ISNULL(MAX(f.December), 0) + ISNULL(MAX(g.December), 0) + ISNULL(MAX(h.December), 0) + ISNULL(MAX(i.December), 0) + ISNULL(MAX(j.December), 0) + ISNULL(MAX(k.December), 0) + ISNULL(MAX(l.December), 0) + ISNULL(MAX(m.December), 0) + ISNULL(MAX(z.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '11.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '11.B'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '11.C'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '11.D'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
		ON base.Sort = e.Sort
		AND e.Sort = '11.E'
		AND e.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse f
		ON base.Sort = f.Sort
		AND f.Sort = '11.F'
		AND f.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse g
		ON base.Sort = g.Sort
		AND g.Sort = '11.G'
		AND g.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse h
		ON base.Sort = h.Sort
		AND h.Sort = '11.H'
		AND h.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse i
		ON base.Sort = i.Sort
		AND i.Sort = '11.I'
		AND i.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse j
		ON base.Sort = j.sort
		AND j.Sort = '11.J'
		AND j.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse k
		ON base.Sort = k.sort
		AND k.Sort = '11.K'
		AND k.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse l
		ON base.Sort = l.sort
		AND l.Sort = '11.L'
		AND l.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse m
		ON base.Sort = m.sort
		AND m.Sort = '11.M'
		AND m.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse z
		ON base.Sort = z.sort
		AND z.Sort = '11.Z'
		AND z.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'ValidationO'
		,'11.Z.02'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) - ISNULL(MAX(c.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) - ISNULL(MAX(c.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) - ISNULL(MAX(c.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) - ISNULL(MAX(c.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) - ISNULL(MAX(c.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) - ISNULL(MAX(c.June), 0) 
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) - ISNULL(MAX(c.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) - ISNULL(MAX(c.August), 0) 
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) - ISNULL(MAX(c.September), 0) 
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) - ISNULL(MAX(c.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) - ISNULL(MAX(c.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) - ISNULL(MAX(c.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.C.03'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.D.03'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '11.Z.01'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'CalculationP'
		,'12.Z.01'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0) + ISNULL(MAX(f.January), 0) + ISNULL(MAX(g.January), 0) + ISNULL(MAX(h.January), 0) + ISNULL(MAX(i.January), 0) + ISNULL(MAX(j.January), 0) + ISNULL(MAX(k.January), 0) + ISNULL(MAX(l.January), 0) + ISNULL(MAX(m.January), 0) + ISNULL(MAX(z.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0) + ISNULL(MAX(f.February), 0) + ISNULL(MAX(g.February), 0) + ISNULL(MAX(h.February), 0) + ISNULL(MAX(i.February), 0) + ISNULL(MAX(j.February), 0) + ISNULL(MAX(k.February), 0) + ISNULL(MAX(l.February), 0) + ISNULL(MAX(m.February), 0) + ISNULL(MAX(z.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) + ISNULL(MAX(e.March), 0) + ISNULL(MAX(f.March), 0) + ISNULL(MAX(g.March), 0) + ISNULL(MAX(h.March), 0) + ISNULL(MAX(i.March), 0) + ISNULL(MAX(j.March), 0) + ISNULL(MAX(k.March), 0) + ISNULL(MAX(l.March), 0) + ISNULL(MAX(m.March), 0) + ISNULL(MAX(z.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) + ISNULL(MAX(f.April), 0) + ISNULL(MAX(g.April), 0) + ISNULL(MAX(h.April), 0) + ISNULL(MAX(i.April), 0) + ISNULL(MAX(j.April), 0) + ISNULL(MAX(k.April), 0) + ISNULL(MAX(l.April), 0) + ISNULL(MAX(m.April), 0) + ISNULL(MAX(z.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0) + ISNULL(MAX(f.May), 0) + ISNULL(MAX(g.May), 0) + ISNULL(MAX(h.May), 0) + ISNULL(MAX(i.May), 0) + ISNULL(MAX(j.May), 0) + ISNULL(MAX(k.May), 0) + ISNULL(MAX(l.May), 0) + ISNULL(MAX(m.May), 0) + ISNULL(MAX(z.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0) + ISNULL(MAX(f.June), 0) + ISNULL(MAX(g.June), 0) + ISNULL(MAX(h.June), 0) + ISNULL(MAX(i.June), 0) + ISNULL(MAX(j.June), 0) + ISNULL(MAX(k.June), 0) + ISNULL(MAX(l.June), 0) + ISNULL(MAX(m.June), 0) + ISNULL(MAX(z.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0) + ISNULL(MAX(f.July), 0) + ISNULL(MAX(g.July), 0) + ISNULL(MAX(h.July), 0) + ISNULL(MAX(i.July), 0) + ISNULL(MAX(j.July), 0) + ISNULL(MAX(k.July), 0) + ISNULL(MAX(l.July), 0) + ISNULL(MAX(m.July), 0) + ISNULL(MAX(z.July), 0)
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0) + ISNULL(MAX(f.August), 0) + ISNULL(MAX(g.August), 0) + ISNULL(MAX(h.August), 0) + ISNULL(MAX(i.August), 0) + ISNULL(MAX(j.August), 0) + ISNULL(MAX(k.August), 0) + ISNULL(MAX(l.August), 0) + ISNULL(MAX(m.August), 0) + ISNULL(MAX(z.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0) + ISNULL(MAX(f.September), 0) + ISNULL(MAX(g.September), 0) + ISNULL(MAX(h.September), 0) + ISNULL(MAX(i.September), 0) + ISNULL(MAX(j.September), 0) + ISNULL(MAX(k.September), 0) + ISNULL(MAX(l.September), 0) + ISNULL(MAX(m.September), 0) + ISNULL(MAX(z.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) + ISNULL(MAX(f.October), 0) + ISNULL(MAX(g.October), 0) + ISNULL(MAX(h.October), 0) + ISNULL(MAX(i.October), 0) + ISNULL(MAX(j.October), 0) + ISNULL(MAX(k.October), 0) + ISNULL(MAX(l.October), 0) + ISNULL(MAX(m.October), 0) + ISNULL(MAX(z.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) + ISNULL(MAX(f.November), 0) + ISNULL(MAX(g.November), 0) + ISNULL(MAX(h.November), 0) + ISNULL(MAX(i.November), 0) + ISNULL(MAX(j.November), 0) + ISNULL(MAX(k.November), 0) + ISNULL(MAX(l.November), 0) + ISNULL(MAX(m.November), 0) + ISNULL(MAX(z.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0) + ISNULL(MAX(f.December), 0) + ISNULL(MAX(g.December), 0) + ISNULL(MAX(h.December), 0) + ISNULL(MAX(i.December), 0) + ISNULL(MAX(j.December), 0) + ISNULL(MAX(k.December), 0) + ISNULL(MAX(l.December), 0) + ISNULL(MAX(m.December), 0) + ISNULL(MAX(z.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '12.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '12.B'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '12.C'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '12.D'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
		ON base.Sort = e.Sort
		AND e.Sort = '12.E'
		AND e.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse f
		ON base.Sort = f.Sort
		AND f.Sort = '12.F'
		AND f.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse g
		ON base.Sort = g.Sort
		AND g.Sort = '12.G'
		AND g.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse h
		ON base.Sort = h.Sort
		AND h.Sort = '12.H'
		AND h.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse i
		ON base.Sort = i.Sort
		AND i.Sort = '12.I'
		AND i.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse j
		ON base.Sort = j.sort
		AND j.Sort = '12.J'
		AND j.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse k
		ON base.Sort = k.sort
		AND k.Sort = '12.K'
		AND k.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse l
		ON base.Sort = l.sort
		AND l.Sort = '12.L'
		AND l.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse m
		ON base.Sort = m.sort
		AND m.Sort = '12.M'
		AND m.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse z
		ON base.Sort = z.sort
		AND z.Sort = '12.Z'
		AND z.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear


	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'ValidationP'
		,'12.Z.02'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) - ISNULL(MAX(c.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) - ISNULL(MAX(c.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) - ISNULL(MAX(c.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) - ISNULL(MAX(c.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) - ISNULL(MAX(c.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) - ISNULL(MAX(c.June), 0) 
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) - ISNULL(MAX(c.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) - ISNULL(MAX(c.August), 0) 
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) - ISNULL(MAX(c.September), 0) 
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) - ISNULL(MAX(c.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) - ISNULL(MAX(c.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) - ISNULL(MAX(c.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '05.C.02'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '05.D.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '12.Z.01'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'PositiveOrReactiveTest'
		,'04.A.01.A'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0) + ISNULL(MAX(f.January), 0) + ISNULL(MAX(g.January), 0) + ISNULL(MAX(h.January), 0) + ISNULL(MAX(i.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0) + ISNULL(MAX(f.February), 0) + ISNULL(MAX(g.February), 0) + ISNULL(MAX(h.February), 0) + ISNULL(MAX(i.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) + ISNULL(MAX(e.March), 0) + ISNULL(MAX(f.March), 0) + ISNULL(MAX(g.March), 0) + ISNULL(MAX(h.March), 0) + ISNULL(MAX(i.March), 0) 
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) + ISNULL(MAX(f.April), 0) + ISNULL(MAX(g.April), 0) + ISNULL(MAX(h.April), 0) + ISNULL(MAX(i.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0) + ISNULL(MAX(f.May), 0) + ISNULL(MAX(g.May), 0) + ISNULL(MAX(h.May), 0) + ISNULL(MAX(i.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0) + ISNULL(MAX(f.June), 0) + ISNULL(MAX(g.June), 0) + ISNULL(MAX(h.June), 0) + ISNULL(MAX(i.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0) + ISNULL(MAX(f.July), 0) + ISNULL(MAX(g.July), 0) + ISNULL(MAX(h.July), 0) + ISNULL(MAX(i.July), 0)
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0) + ISNULL(MAX(f.August), 0) + ISNULL(MAX(g.August), 0) + ISNULL(MAX(h.August), 0) + ISNULL(MAX(i.August), 0) 
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0) + ISNULL(MAX(f.September), 0) + ISNULL(MAX(g.September), 0) + ISNULL(MAX(h.September), 0) + ISNULL(MAX(i.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) + ISNULL(MAX(f.October), 0) + ISNULL(MAX(g.October), 0) + ISNULL(MAX(h.October), 0) + ISNULL(MAX(i.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) + ISNULL(MAX(f.November), 0) + ISNULL(MAX(g.November), 0) + ISNULL(MAX(h.November), 0) + ISNULL(MAX(i.November), 0)
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0) + ISNULL(MAX(f.December), 0) + ISNULL(MAX(g.December), 0) + ISNULL(MAX(h.December), 0) + ISNULL(MAX(i.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '04.A.01.A.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.A.01.A.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '04.A.01.A.03'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '04.A.01.A.04'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
		ON base.Sort = e.Sort
		AND e.Sort = '04.A.01.A.05'
		AND e.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse f
		ON base.Sort = f.Sort
		AND f.Sort = '04.A.01.A.06'
		AND f.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse g
		ON base.Sort = g.Sort
		AND g.Sort = '04.A.01.A.07'
		AND g.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse h
		ON base.Sort = h.Sort
		AND h.Sort = '04.A.01.A.08'
		AND h.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse i
		ON base.Sort = i.Sort
		AND i.Sort = '04.A.01.A.09'
		AND i.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'MedicalRecordAutopsyFindings'
		,'04.A.01.C'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0)  + ISNULL(MAX(e.January), 0) + ISNULL(MAX(f.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0) + ISNULL(MAX(f.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) + ISNULL(MAX(e.March), 0) + ISNULL(MAX(f.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0)  + ISNULL(MAX(e.April), 0) + ISNULL(MAX(f.April), 0)
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0) + ISNULL(MAX(f.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0) + ISNULL(MAX(f.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0) + ISNULL(MAX(f.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0) + ISNULL(MAX(f.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0)  + ISNULL(MAX(e.September), 0) + ISNULL(MAX(f.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) + ISNULL(MAX(f.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) + ISNULL(MAX(f.November), 0)  
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0) + ISNULL(MAX(f.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '04.A.01.C.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.A.01.C.02'
		AND b.ReportYear = @reportYear 
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '04.A.01.C.03'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '04.A.01.C.04'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
		ON Base.Sort = e.Sort
		AND e.Sort = '04.A.01.C.05'
		AND e.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse f
		ON base.Sort = f.Sort
		AND f.Sort = '04.A.01.C.06'
		AND f.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'MedicalSocialHistoryInterview'
		,'04.A.01.D'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) 
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) 
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) 
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) 
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '04.A.01.D.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.A.01.D.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '04.A.01.D.03'
		AND c.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'TissueSuitabilityB'
		,'04.A.02.B'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) + ISNULL(MAX(e.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0)
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '04.A.02.B.01'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.A.02.B.02'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '04.A.02.B.03'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '04.A.02.B.04'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
		ON base.Sort = e.Sort
		AND e.Sort = '04.A.02.B.05'
		AND e.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'TissueSuitability'
		,'04.A.02'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) 
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) 
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) 
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0)
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '04.A.02.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.A.02.B'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '04.A.02.C'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '04.A.02.D'
		AND d.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	INSERT INTO [dbo].[EBAAReportWarehouse]
			   ([Label]
			   ,[Sort]
			   ,[ReportYear]
			   ,[YearCalculation]
			   ,[January]
			   ,[February]
			   ,[March]
			   ,[April]
			   ,[May]
			   ,[June]
			   ,[July]
			   ,[August]
			   ,[September]
			   ,[October]
			   ,[November]
			   ,[December])
	SELECT 
		 'QualityIssue'
		,'04.A.03'
		,@reportYear
		,NULL as YearCalculation
		,ISNULL(MAX(a.January), 0) + ISNULL(MAX(b.January), 0) + ISNULL(MAX(c.January), 0) + ISNULL(MAX(d.January), 0) + ISNULL(MAX(e.January), 0)
		,ISNULL(MAX(a.February), 0) + ISNULL(MAX(b.February), 0) + ISNULL(MAX(c.February), 0) + ISNULL(MAX(d.February), 0) + ISNULL(MAX(e.February), 0)
		,ISNULL(MAX(a.March), 0) + ISNULL(MAX(b.March), 0) + ISNULL(MAX(c.March), 0) + ISNULL(MAX(d.March), 0) + ISNULL(MAX(e.March), 0)
		,ISNULL(MAX(a.April), 0) + ISNULL(MAX(b.April), 0) + ISNULL(MAX(c.April), 0) + ISNULL(MAX(d.April), 0) + ISNULL(MAX(e.April), 0) 
		,ISNULL(MAX(a.May), 0) + ISNULL(MAX(b.May), 0) + ISNULL(MAX(c.May), 0) + ISNULL(MAX(d.May), 0) + ISNULL(MAX(e.May), 0)
		,ISNULL(MAX(a.June), 0) + ISNULL(MAX(b.June), 0) + ISNULL(MAX(c.June), 0) + ISNULL(MAX(d.June), 0) + ISNULL(MAX(e.June), 0)
		,ISNULL(MAX(a.July), 0) + ISNULL(MAX(b.July), 0) + ISNULL(MAX(c.July), 0) + ISNULL(MAX(d.July), 0) + ISNULL(MAX(e.July), 0)
		,ISNULL(MAX(a.August), 0) + ISNULL(MAX(b.August), 0) + ISNULL(MAX(c.August), 0) + ISNULL(MAX(d.August), 0) + ISNULL(MAX(e.August), 0)
		,ISNULL(MAX(a.September), 0) + ISNULL(MAX(b.September), 0) + ISNULL(MAX(c.September), 0) + ISNULL(MAX(d.September), 0) + ISNULL(MAX(e.September), 0)
		,ISNULL(MAX(a.October), 0) + ISNULL(MAX(b.October), 0) + ISNULL(MAX(c.October), 0) + ISNULL(MAX(d.October), 0) + ISNULL(MAX(e.October), 0) 
		,ISNULL(MAX(a.November), 0) + ISNULL(MAX(b.November), 0) + ISNULL(MAX(c.November), 0) + ISNULL(MAX(d.November), 0) + ISNULL(MAX(e.November), 0) 
		,ISNULL(MAX(a.December), 0) + ISNULL(MAX(b.December), 0) + ISNULL(MAX(c.December), 0) + ISNULL(MAX(d.December), 0) + ISNULL(MAX(e.December), 0)
	FROM EBAAReportWarehouse base
	LEFT JOIN EBAAReportWarehouse a
		ON base.Sort = a.Sort
		AND a.Sort = '04.A.03.A'
		AND a.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse b
		ON base.Sort = b.Sort
		AND b.Sort = '04.A.03.B'
		AND b.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse c
		ON Base.Sort = c.Sort
		AND c.Sort = '04.A.03.C'
		AND c.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse d
		ON base.Sort = d.Sort
		AND d.Sort = '04.A.03.D'
		AND d.ReportYear = @reportYear
	LEFT JOIN EBAAReportWarehouse e
		ON base.Sort = e.Sort
		AND e.Sort = '04.A.03.E'
		AND e.ReportYear = @reportYear
	WHERE base.ReportYear = @reportYear

	DROP TABLE #referrals

End



GO


