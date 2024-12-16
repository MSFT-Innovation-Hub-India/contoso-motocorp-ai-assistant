/****** Object:  StoredProcedure [dbo].[CreateServiceSchedule]    Script Date: 16-12-2024 09:58:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateServiceSchedule]
    @SelectedSlotStart DATETIME,
    @VehicleID INT,
    @ServiceTypeID INT
AS
BEGIN
    DECLARE @NewScheduleID INT;
    DECLARE @NewAppointmentID INT;
    DECLARE @AvailableTechnicianID INT;
    DECLARE @ServiceDuration INT;
    DECLARE @SelectedSlotEnd DATETIME;

    -- Calculate the end time of the selected slot based on the service duration
    -- Retrieve the duration of the selected service type
    SELECT @ServiceDuration = duration_minutes
    FROM Service_Types
    WHERE service_type_id = @ServiceTypeID;

    -- Calculate the end time of the service slot
    SET @SelectedSlotEnd = DATEADD(MINUTE, @ServiceDuration, @SelectedSlotStart);

    -- Retrieve the current maximum schedule_id and compute the new ID
    SELECT @NewScheduleID = ISNULL(MAX(schedule_id), 0) + 1 FROM Service_Schedules;

    -- Retrieve the current maximum appointment_id and compute the new ID
    SELECT @NewAppointmentID = ISNULL(MAX(appointment_id), 0) + 1 FROM Appointments;

    -- Find an available technician who does not have an appointment during the selected slot
    SELECT TOP 1 @AvailableTechnicianID = t.technician_id
    FROM Technicians t
    WHERE NOT EXISTS (
        SELECT 1
        FROM Appointments a
        INNER JOIN Service_Schedules ss ON a.schedule_id = ss.schedule_id
        WHERE a.technician_id = t.technician_id
          AND ss.service_date = CAST(@SelectedSlotStart AS DATE)
          AND (
              (ss.start_time <= CAST(@SelectedSlotStart AS TIME) AND ss.end_time > CAST(@SelectedSlotStart AS TIME)) OR
              (ss.start_time < CAST(@SelectedSlotEnd AS TIME) AND ss.end_time >= CAST(@SelectedSlotEnd AS TIME))
          )
    );

    -- Check if an available technician was found
    IF @AvailableTechnicianID IS NOT NULL
    BEGIN
        -- Insert the new service schedule into the Service_Schedules table and return the inserted record
        INSERT INTO Service_Schedules (schedule_id, vehicle_id, service_type_id, service_date, start_time, end_time, status)
        OUTPUT INSERTED.schedule_id, INSERTED.vehicle_id, INSERTED.service_type_id, INSERTED.service_date, INSERTED.start_time, INSERTED.end_time, INSERTED.status
        VALUES (
            @NewScheduleID,
            @VehicleID,
            @ServiceTypeID,
            CAST(@SelectedSlotStart AS DATE),
            CAST(@SelectedSlotStart AS TIME),
            CAST(@SelectedSlotEnd AS TIME),
            'Scheduled'
        );

        -- Insert the new appointment into the Appointments table and return the inserted record
        INSERT INTO Appointments (appointment_id, schedule_id, technician_id, appointment_status)
        OUTPUT INSERTED.appointment_id, INSERTED.schedule_id, INSERTED.technician_id, INSERTED.appointment_status
        VALUES (
            @NewAppointmentID,
            @NewScheduleID,
            @AvailableTechnicianID,
            'Assigned'
        );

        -- Retrieve and display the details of the scheduled service along with the assigned technician
        SELECT
            ss.schedule_id AS ScheduleID,
            ss.service_date AS ServiceDate,
            ss.start_time AS StartTime,
            ss.end_time AS EndTime,
            ss.status AS ScheduleStatus,
            st.service_name AS ServiceType,
            t.technician_id AS TechnicianID,
            t.name AS TechnicianName,
            t.specialization AS TechnicianSpecialization
        FROM
            Service_Schedules ss
            INNER JOIN Service_Types st ON ss.service_type_id = st.service_type_id
            INNER JOIN Appointments a ON ss.schedule_id = a.schedule_id
            INNER JOIN Technicians t ON a.technician_id = t.technician_id
        WHERE
            ss.schedule_id = @NewScheduleID;

        PRINT 'Appointment and service schedule successfully created.';
    END
    ELSE
    BEGIN
        PRINT 'No available technician found for the selected time slot.';
    END
END;