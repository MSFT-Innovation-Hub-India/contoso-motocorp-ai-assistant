/****** Object:  StoredProcedure [dbo].[InsertServiceFeedback]    Script Date: 16-12-2024 10:01:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[InsertServiceFeedback]
    @schedule_id INT,
    @customer_id INT,
    @feedback_text NVARCHAR(MAX),
    @feedback_vector_json NVARCHAR(MAX), -- Accept JSON string
    @rating_quality_of_work INT,
    @rating_timeliness INT,
    @rating_politeness INT,
    @rating_cleanliness INT,
    @rating_overall_experience INT,
    @feedback_date DATE
AS
BEGIN
    SET NOCOUNT ON;

	
drop table if exists #vectors
create table #vectors
(
    id int not null identity primary key,
    vector vector(1536) not null
);
	insert into #vectors (vector)
select 
    cast(a as vector(1536))
from
    ( values 
        (@feedback_vector_json)
    ) V(a)
;
declare @v1 vector(1536) = (SELECT vector FROM #vectors WHERE id = 1)

    -- Insert the feedback data into the Service_Feedback table
    INSERT INTO Service_Feedback (
        schedule_id,
        customer_id,
        feedback_text,
        feedback_vector,
        rating_quality_of_work,
        rating_timeliness,
        rating_politeness,
        rating_cleanliness,
        rating_overall_experience,
        feedback_date
    ) VALUES (
        @schedule_id,
        @customer_id,
        @feedback_text,
        @v1,
        @rating_quality_of_work,
        @rating_timeliness,
        @rating_politeness,
        @rating_cleanliness,
        @rating_overall_experience,
        @feedback_date
    );

    PRINT 'Feedback inserted successfully for schedule_id: ' + CAST(@schedule_id AS NVARCHAR);
END;
