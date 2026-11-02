/* =====================================================================
   PROJECT    : Organic Farming Certification Management System
   FILE       : Organic_Farming_Certification.sql
   COLLEGE    : A D Patel Institute of Technology (ADIT), CVM University
   DEPARTMENT : Information Technology
   SUBJECT    : DBMS (AI-2)            ACADEMIC YEAR : 2026-2027
   STUDENT    : Swayam Trusharkumar Kapatel
   ENROLLMENT : 12502120601112

   VERSION ASSUMPTIONS
   - Oracle Database 12c or later (tested design target: 12c / 19c / 21c).
     Only standard features are used (sequences, PL/SQL, REGEXP_LIKE).
     Sequences are used instead of identity columns so the script also works
     on 11g.
   - Oracle SQL Developer 20.x or later.
   - Run as a normal schema user that can CREATE TABLE, SEQUENCE, VIEW,
     PROCEDURE, FUNCTION and TRIGGER (e.g. a student/practice schema).

   HOW TO RUN
   1. Open this file in SQL Developer, connect to your schema.
   2. Click "Run Script" (F5), NOT "Run Statement" (Ctrl+Enter).
   3. Open View > Dbms Output, add your connection, so DBMS_OUTPUT text shows.
   4. Run the whole file ONCE from top to bottom. It is re-runnable because
      Section 1 drops every object it owns first.

   WHEN TO USE THE "/" LINE
   - Put "/" alone on a line after every PL/SQL unit: anonymous blocks
     (DECLARE/BEGIN/END;), CREATE PROCEDURE, CREATE FUNCTION, CREATE TRIGGER.
     It tells SQL Developer "the PL/SQL text has ended, run it now".
   - Do NOT put "/" after plain SQL (SELECT, INSERT, UPDATE, CREATE TABLE...);
     those end with a semicolon only.

   IMPORTANT NOTES ON DATES
   - Sample dates are written relative to SYSDATE (e.g. TRUNC(SYSDATE) - 35)
     so that "expired" and "expiring soon" data stay correct whenever you run
     the script. Expected outputs quoted in comments assume the script is run
     on 30-OCT-2026; on another day the dates and day-counts shift.

   OUTPUT LABELS
   - Comments marked "EXPECTED OUTPUT (SIMULATED)" were worked out by hand
     from the sample data. They were NOT produced by running the code.
     Compare them with your real SQL Developer output when you run it.
   ===================================================================== */

SET SERVEROUTPUT ON SIZE UNLIMITED;

/* =====================================================================
   SECTION 1 OF 13 : DATABASE SETUP AND CLEANUP
   Drops every project object (if present) so the script can be re-run.
   Nothing here touches objects with other names.
   ===================================================================== */
BEGIN
  FOR r IN (SELECT view_name AS n FROM user_views
            WHERE view_name IN ('V_FARMER_CERTIFICATION_INFO','V_EXPIRING_CERTIFICATES')) LOOP
    EXECUTE IMMEDIATE 'DROP VIEW ' || r.n;
  END LOOP;

  FOR r IN (SELECT table_name AS n FROM user_tables
            WHERE table_name IN ('CERTIFICATES','INSPECTIONS',
                                 'CERTIFICATION_APPLICATIONS','FARMS','FARMERS')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || r.n || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;

  FOR r IN (SELECT object_type AS t, object_name AS n FROM user_objects
            WHERE object_type IN ('PROCEDURE','FUNCTION','TRIGGER')
              AND object_name IN ('SP_SUBMIT_APPLICATION','SP_RECORD_INSPECTION',
                                  'FN_DAYS_TO_EXPIRY','FN_AVG_COMPLIANCE_SCORE',
                                  'TRG_CERT_VALIDATE')) LOOP
    EXECUTE IMMEDIATE 'DROP ' || r.t || ' ' || r.n;
  END LOOP;

  FOR r IN (SELECT sequence_name AS n FROM user_sequences
            WHERE sequence_name IN ('SEQ_FARMER','SEQ_FARM','SEQ_APPLICATION',
                                    'SEQ_INSPECTION','SEQ_CERTIFICATE')) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || r.n;
  END LOOP;
END;
/

/* =====================================================================
   SECTION 2 OF 13 : TABLE CREATION
   Parent tables first, then child tables (so foreign keys are valid).
   ===================================================================== */

CREATE TABLE farmers (
  farmer_id      NUMBER(6)     CONSTRAINT pk_farmers PRIMARY KEY,
  farmer_name    VARCHAR2(100) NOT NULL,
  phone          VARCHAR2(10)  NOT NULL,
  email          VARCHAR2(100),
  address        VARCHAR2(200) NOT NULL,
  registered_on  DATE          DEFAULT SYSDATE NOT NULL,
  CONSTRAINT uq_farmers_phone UNIQUE (phone),
  CONSTRAINT uq_farmers_email UNIQUE (email),
  CONSTRAINT ck_farmers_phone CHECK (REGEXP_LIKE(phone, '^[0-9]{10}$')),
  CONSTRAINT ck_farmers_email CHECK (email IS NULL OR REGEXP_LIKE(email, '^[^@ ]+@[^@ ]+\.[^@ ]+$'))
);

CREATE TABLE farms (
  farm_id      NUMBER(6)     CONSTRAINT pk_farms PRIMARY KEY,
  farmer_id    NUMBER(6)     NOT NULL,
  farm_name    VARCHAR2(100) NOT NULL,
  location     VARCHAR2(150) NOT NULL,
  area_acres   NUMBER(8,2)   NOT NULL,
  soil_type    VARCHAR2(20)  NOT NULL,
  CONSTRAINT fk_farms_farmer FOREIGN KEY (farmer_id) REFERENCES farmers (farmer_id),
  CONSTRAINT uq_farms_farmer_name UNIQUE (farmer_id, farm_name),
  CONSTRAINT ck_farms_area CHECK (area_acres > 0),
  CONSTRAINT ck_farms_soil CHECK (soil_type IN ('Black','Red','Alluvial','Loamy','Sandy','Clay','Laterite'))
);

CREATE TABLE certification_applications (
  application_id       NUMBER(6)    CONSTRAINT pk_applications PRIMARY KEY,
  farm_id              NUMBER(6)    NOT NULL,
  application_date     DATE         DEFAULT SYSDATE NOT NULL,
  status               VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
  requested_cert_type  VARCHAR2(20) NOT NULL,
  CONSTRAINT fk_app_farm FOREIGN KEY (farm_id) REFERENCES farms (farm_id),
  CONSTRAINT ck_app_status CHECK (status IN ('PENDING','UNDER_INSPECTION','APPROVED','REJECTED')),
  CONSTRAINT ck_app_type CHECK (requested_cert_type IN ('NPOP','NOP-USDA','PGS-INDIA','ORGANIC-EU'))
);

CREATE TABLE inspections (
  inspection_id     NUMBER(6)    CONSTRAINT pk_inspections PRIMARY KEY,
  application_id    NUMBER(6)    NOT NULL,
  inspector_name    VARCHAR2(100) NOT NULL,
  inspection_date   DATE         DEFAULT SYSDATE NOT NULL,
  findings          VARCHAR2(500),
  compliance_score  NUMBER(5,2)  NOT NULL,
  result            VARCHAR2(12) NOT NULL,
  CONSTRAINT fk_insp_app FOREIGN KEY (application_id) REFERENCES certification_applications (application_id),
  CONSTRAINT ck_insp_score CHECK (compliance_score BETWEEN 0 AND 100),
  CONSTRAINT ck_insp_result CHECK (result IN ('PASS','CONDITIONAL','FAIL'))
);

CREATE TABLE certificates (
  certificate_id      NUMBER(6)    CONSTRAINT pk_certificates PRIMARY KEY,
  application_id      NUMBER(6)    NOT NULL,
  certificate_number  VARCHAR2(30) NOT NULL,
  issue_date          DATE         DEFAULT SYSDATE NOT NULL,
  expiry_date         DATE         NOT NULL,
  certificate_status  VARCHAR2(10) DEFAULT 'ACTIVE' NOT NULL,
  CONSTRAINT fk_cert_app FOREIGN KEY (application_id) REFERENCES certification_applications (application_id),
  CONSTRAINT uq_cert_number UNIQUE (certificate_number),
  CONSTRAINT uq_cert_application UNIQUE (application_id),
  CONSTRAINT ck_cert_status CHECK (certificate_status IN ('ACTIVE','EXPIRED','REVOKED')),
  CONSTRAINT ck_cert_dates CHECK (expiry_date > issue_date)
);

/* =====================================================================
   SECTION 3 OF 13 : SEQUENCES (primary-key generators)
   NOCACHE keeps numbers consecutive so expected outputs are predictable.
   Note: sequences are NOT rolled back by ROLLBACK, so gaps can appear.
   ===================================================================== */
CREATE SEQUENCE seq_farmer      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_farm        START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_application START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_inspection  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_certificate START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

/* =====================================================================
   SECTION 4 OF 13 : SAMPLE DATA
   6 farmers, 7 farms, 10 applications, 7 inspections, 5 certificates.
   Rows are inserted parent-first so every foreign key is valid.
   Because the sequences start at 1 on a fresh run, the IDs used in the
   child rows (farmer 1..6, farm 1..7, application 1..10) are guaranteed.
   ===================================================================== */

-- FARMERS (farmer 6 deliberately has no farm yet)
INSERT INTO farmers (farmer_id, farmer_name, phone, email, address, registered_on)
VALUES (seq_farmer.NEXTVAL, 'Ramesh Patel', '9825012345', 'ramesh.patel@example.com', 'Vadtal, Anand, Gujarat', TRUNC(SYSDATE) - 500);
INSERT INTO farmers (farmer_id, farmer_name, phone, email, address, registered_on)
VALUES (seq_farmer.NEXTVAL, 'Sunita Desai', '9898123456', 'sunita.desai@example.com', 'Borsad, Anand, Gujarat', TRUNC(SYSDATE) - 450);
INSERT INTO farmers (farmer_id, farmer_name, phone, email, address, registered_on)
VALUES (seq_farmer.NEXTVAL, 'Kiran Solanki', '9879234567', 'kiran.solanki@example.com', 'Petlad, Anand, Gujarat', TRUNC(SYSDATE) - 300);
INSERT INTO farmers (farmer_id, farmer_name, phone, email, address, registered_on)
VALUES (seq_farmer.NEXTVAL, 'Meena Parmar', '9726345678', 'meena.parmar@example.com', 'Khambhat, Anand, Gujarat', TRUNC(SYSDATE) - 200);
INSERT INTO farmers (farmer_id, farmer_name, phone, email, address, registered_on)
VALUES (seq_farmer.NEXTVAL, 'Harshad Chauhan', '9913456789', 'harshad.chauhan@example.com', 'Umreth, Anand, Gujarat', TRUNC(SYSDATE) - 360);
INSERT INTO farmers (farmer_id, farmer_name, phone, email, address, registered_on)
VALUES (seq_farmer.NEXTVAL, 'Anita Rathod', '9427567890', 'anita.rathod@example.com', 'Nadiad, Kheda, Gujarat', TRUNC(SYSDATE) - 30);

-- FARMS (farm 7 deliberately has no application yet)
INSERT INTO farms (farm_id, farmer_id, farm_name, location, area_acres, soil_type)
VALUES (seq_farm.NEXTVAL, 1, 'Patel Organic Fields', 'Vadtal, Anand', 12.50, 'Loamy');
INSERT INTO farms (farm_id, farmer_id, farm_name, location, area_acres, soil_type)
VALUES (seq_farm.NEXTVAL, 1, 'Patel Millet Plot', 'Vadtal, Anand', 4.00, 'Black');
INSERT INTO farms (farm_id, farmer_id, farm_name, location, area_acres, soil_type)
VALUES (seq_farm.NEXTVAL, 2, 'Desai Green Acres', 'Borsad, Anand', 8.75, 'Alluvial');
INSERT INTO farms (farm_id, farmer_id, farm_name, location, area_acres, soil_type)
VALUES (seq_farm.NEXTVAL, 3, 'Solanki Pulse Farm', 'Petlad, Anand', 15.00, 'Sandy');
INSERT INTO farms (farm_id, farmer_id, farm_name, location, area_acres, soil_type)
VALUES (seq_farm.NEXTVAL, 4, 'Parmar Spice Garden', 'Khambhat, Anand', 6.25, 'Clay');
INSERT INTO farms (farm_id, farmer_id, farm_name, location, area_acres, soil_type)
VALUES (seq_farm.NEXTVAL, 5, 'Chauhan Mango Orchard', 'Umreth, Anand', 20.00, 'Red');
INSERT INTO farms (farm_id, farmer_id, farm_name, location, area_acres, soil_type)
VALUES (seq_farm.NEXTVAL, 2, 'Desai Vegetable Plot', 'Borsad, Anand', 3.50, 'Loamy');

-- CERTIFICATION_APPLICATIONS
INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
VALUES (seq_application.NEXTVAL, 1, TRUNC(SYSDATE) - 430, 'APPROVED', 'NPOP');
INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
VALUES (seq_application.NEXTVAL, 3, TRUNC(SYSDATE) - 375, 'APPROVED', 'NPOP');
INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
VALUES (seq_application.NEXTVAL, 4, TRUNC(SYSDATE) - 230, 'APPROVED', 'PGS-INDIA');
INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
VALUES (seq_application.NEXTVAL, 5, TRUNC(SYSDATE) - 130, 'APPROVED', 'NOP-USDA');
INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
VALUES (seq_application.NEXTVAL, 6, TRUNC(SYSDATE) - 340, 'APPROVED', 'ORGANIC-EU');
INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
VALUES (seq_application.NEXTVAL, 2, TRUNC(SYSDATE) - 20, 'PENDING', 'PGS-INDIA');
INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
VALUES (seq_application.NEXTVAL, 1, TRUNC(SYSDATE) - 15, 'UNDER_INSPECTION', 'NPOP');
INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
VALUES (seq_application.NEXTVAL, 6, TRUNC(SYSDATE) - 5, 'PENDING', 'NOP-USDA');
INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
VALUES (seq_application.NEXTVAL, 5, TRUNC(SYSDATE) - 55, 'REJECTED', 'ORGANIC-EU');
INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
VALUES (seq_application.NEXTVAL, 3, TRUNC(SYSDATE) - 3, 'PENDING', 'NOP-USDA');

-- INSPECTIONS
INSERT INTO inspections (inspection_id, application_id, inspector_name, inspection_date, findings, compliance_score, result)
VALUES (seq_inspection.NEXTVAL, 1, 'A. K. Joshi', TRUNC(SYSDATE) - 420, 'Crop rotation and compost records verified; no prohibited inputs found.', 92.50, 'PASS');
INSERT INTO inspections (inspection_id, application_id, inspector_name, inspection_date, findings, compliance_score, result)
VALUES (seq_inspection.NEXTVAL, 2, 'Dr. P. S. Mehta', TRUNC(SYSDATE) - 365, 'Buffer zones maintained; minor gaps in seed records.', 88.00, 'PASS');
INSERT INTO inspections (inspection_id, application_id, inspector_name, inspection_date, findings, compliance_score, result)
VALUES (seq_inspection.NEXTVAL, 3, 'A. K. Joshi', TRUNC(SYSDATE) - 220, 'Organic manure used; pest management plan documented.', 85.50, 'PASS');
INSERT INTO inspections (inspection_id, application_id, inspector_name, inspection_date, findings, compliance_score, result)
VALUES (seq_inspection.NEXTVAL, 4, 'N. R. Trivedi', TRUNC(SYSDATE) - 120, 'Soil tests clean; irrigation water tested and safe.', 90.00, 'PASS');
INSERT INTO inspections (inspection_id, application_id, inspector_name, inspection_date, findings, compliance_score, result)
VALUES (seq_inspection.NEXTVAL, 5, 'Dr. P. S. Mehta', TRUNC(SYSDATE) - 330, 'Orchard managed with bio-pesticides; records complete.', 81.25, 'PASS');
INSERT INTO inspections (inspection_id, application_id, inspector_name, inspection_date, findings, compliance_score, result)
VALUES (seq_inspection.NEXTVAL, 9, 'N. R. Trivedi', TRUNC(SYSDATE) - 55, 'Synthetic fertilizer traces found; records incomplete.', 42.00, 'FAIL');
INSERT INTO inspections (inspection_id, application_id, inspector_name, inspection_date, findings, compliance_score, result)
VALUES (seq_inspection.NEXTVAL, 7, 'A. K. Joshi', TRUNC(SYSDATE) - 10, 'Buffer zone needs improvement; follow-up inspection required.', 62.00, 'CONDITIONAL');

/* CERTIFICATES
   Statuses are not supplied, so they default to 'ACTIVE'. Certificate 1 is
   already past its expiry date, so the trigger created in Section 10 is NOT
   yet present at this point. To keep the data correct, the statuses are
   fixed in the UPDATE below, and the trigger will keep them correct later.
   Certificates need APPROVED applications: applications 1-5 are APPROVED. */
INSERT INTO certificates (certificate_id, application_id, certificate_number, issue_date, expiry_date)
VALUES (seq_certificate.NEXTVAL, 1, 'GJ-ORG-0001', TRUNC(SYSDATE) - 400, TRUNC(SYSDATE) - 35);
INSERT INTO certificates (certificate_id, application_id, certificate_number, issue_date, expiry_date)
VALUES (seq_certificate.NEXTVAL, 2, 'GJ-ORG-0002', TRUNC(SYSDATE) - 345, TRUNC(SYSDATE) + 20);
INSERT INTO certificates (certificate_id, application_id, certificate_number, issue_date, expiry_date)
VALUES (seq_certificate.NEXTVAL, 3, 'GJ-ORG-0003', TRUNC(SYSDATE) - 200, TRUNC(SYSDATE) + 165);
INSERT INTO certificates (certificate_id, application_id, certificate_number, issue_date, expiry_date)
VALUES (seq_certificate.NEXTVAL, 4, 'GJ-ORG-0004', TRUNC(SYSDATE) - 100, TRUNC(SYSDATE) + 265);
INSERT INTO certificates (certificate_id, application_id, certificate_number, issue_date, expiry_date)
VALUES (seq_certificate.NEXTVAL, 5, 'GJ-ORG-0005', TRUNC(SYSDATE) - 310, TRUNC(SYSDATE) + 55);

-- Mark the already-lapsed certificate as EXPIRED (the trigger will do this automatically later).
UPDATE certificates SET certificate_status = 'EXPIRED' WHERE expiry_date < TRUNC(SYSDATE);

COMMIT;

/* =====================================================================
   SECTION 5 OF 13 : SQL QUERIES  (Q1 - Q18)
   Expected outputs assume the script was run on 30-OCT-2026.
   ===================================================================== */

-- Q1. SELECT + ORDER BY: all farmers in alphabetical order.
-- EXPECTED OUTPUT (SIMULATED): 6 rows, Anita Rathod first ... Sunita Desai last.
SELECT farmer_id, farmer_name, phone, address
FROM   farmers
ORDER  BY farmer_name;

-- Q2. WHERE + ORDER BY DESC: farms larger than 10 acres, biggest first.
-- EXPECTED OUTPUT (SIMULATED): Chauhan Mango Orchard 20.00; Solanki Pulse Farm 15.00; Patel Organic Fields 12.50.
SELECT farm_id, farm_name, location, area_acres
FROM   farms
WHERE  area_acres > 10
ORDER  BY area_acres DESC;

-- Q3. INNER JOIN: every farm with its owner (farmers without farms are excluded).
-- EXPECTED OUTPUT (SIMULATED): 7 rows (one per farm).
SELECT fr.farmer_name, fm.farm_name, fm.location, fm.soil_type
FROM   farmers fr
INNER JOIN farms fm ON fm.farmer_id = fr.farmer_id
ORDER  BY fr.farmer_name, fm.farm_name;

-- Q4. LEFT JOIN: all farmers, even those with no registered farm.
-- EXPECTED OUTPUT (SIMULATED): 8 rows; Anita Rathod appears with NULL farm_name.
SELECT fr.farmer_id, fr.farmer_name, fm.farm_name
FROM   farmers fr
LEFT JOIN farms fm ON fm.farmer_id = fr.farmer_id
ORDER  BY fr.farmer_id, fm.farm_id;

-- Q5. GROUP BY + COUNT: number of applications in each status.
-- EXPECTED OUTPUT (SIMULATED): APPROVED 5; PENDING 3; REJECTED 1; UNDER_INSPECTION 1.
SELECT status, COUNT(*) AS total_applications
FROM   certification_applications
GROUP  BY status
ORDER  BY status;

-- Q6. GROUP BY + HAVING: farmers who own more than one farm.
-- EXPECTED OUTPUT (SIMULATED): Ramesh Patel 2; Sunita Desai 2.
SELECT fr.farmer_name, COUNT(fm.farm_id) AS farm_count
FROM   farmers fr
JOIN   farms fm ON fm.farmer_id = fr.farmer_id
GROUP  BY fr.farmer_name
HAVING COUNT(fm.farm_id) > 1
ORDER  BY fr.farmer_name;

-- Q7. COUNT, SUM, AVG, MIN, MAX in one query: summary of farm areas.
-- EXPECTED OUTPUT (SIMULATED): total_farms 7; total_area 70; average_area 10; smallest 3.5; largest 20.
SELECT COUNT(*)          AS total_farms,
       SUM(area_acres)   AS total_area,
       ROUND(AVG(area_acres), 2) AS average_area,
       MIN(area_acres)   AS smallest_farm,
       MAX(area_acres)   AS largest_farm
FROM   farms;

-- Q8. Subquery: farms whose area is above the average farm area.
-- EXPECTED OUTPUT (SIMULATED): Patel Organic Fields 12.5; Solanki Pulse Farm 15; Chauhan Mango Orchard 20.
SELECT farm_name, area_acres
FROM   farms
WHERE  area_acres > (SELECT AVG(area_acres) FROM farms)
ORDER  BY area_acres;

-- Q9. EXISTS: farmers who have at least one APPROVED application.
-- EXPECTED OUTPUT (SIMULATED): 5 farmers (all except Anita Rathod).
SELECT fr.farmer_id, fr.farmer_name
FROM   farmers fr
WHERE  EXISTS (SELECT 1
               FROM   farms fm
               JOIN   certification_applications ca ON ca.farm_id = fm.farm_id
               WHERE  fm.farmer_id = fr.farmer_id
               AND    ca.status = 'APPROVED')
ORDER  BY fr.farmer_id;

-- Q10. NOT EXISTS: farms that have never applied for certification.
-- EXPECTED OUTPUT (SIMULATED): Desai Vegetable Plot.
SELECT fm.farm_id, fm.farm_name
FROM   farms fm
WHERE  NOT EXISTS (SELECT 1 FROM certification_applications ca WHERE ca.farm_id = fm.farm_id);

-- Q11. Pending applications and how many days each has been waiting (date-based).
-- EXPECTED OUTPUT (SIMULATED): application 6 (20 days), 8 (5 days), 10 (3 days).
SELECT ca.application_id, fm.farm_name, fr.farmer_name, ca.application_date,
       TRUNC(SYSDATE) - TRUNC(ca.application_date) AS days_waiting
FROM   certification_applications ca
JOIN   farms fm   ON fm.farm_id = ca.farm_id
JOIN   farmers fr ON fr.farmer_id = fm.farmer_id
WHERE  ca.status = 'PENDING'
ORDER  BY ca.application_date;

-- Q12. Approved applications with the certification type granted.
-- EXPECTED OUTPUT (SIMULATED): application IDs 1 to 5.
SELECT ca.application_id, fm.farm_name, ca.requested_cert_type, ca.application_date
FROM   certification_applications ca
JOIN   farms fm ON fm.farm_id = ca.farm_id
WHERE  ca.status = 'APPROVED'
ORDER  BY ca.application_id;

-- Q13. Expired certificates (expiry date is before today).
-- EXPECTED OUTPUT (SIMULATED): GJ-ORG-0001, Patel Organic Fields, expired 25-SEP-2026, 35 days ago.
SELECT ce.certificate_number, fm.farm_name, ce.expiry_date, ce.certificate_status,
       TRUNC(SYSDATE) - TRUNC(ce.expiry_date) AS days_since_expiry
FROM   certificates ce
JOIN   certification_applications ca ON ca.application_id = ce.application_id
JOIN   farms fm ON fm.farm_id = ca.farm_id
WHERE  ce.expiry_date < TRUNC(SYSDATE)
ORDER  BY ce.expiry_date;

-- Q14. Upcoming renewals: ACTIVE certificates expiring within the next 90 days.
-- EXPECTED OUTPUT (SIMULATED): GJ-ORG-0002 (20 days, 19-NOV-2026); GJ-ORG-0005 (55 days, 24-DEC-2026).
SELECT ce.certificate_number, fr.farmer_name, fr.phone, ce.expiry_date,
       TRUNC(ce.expiry_date) - TRUNC(SYSDATE) AS days_remaining
FROM   certificates ce
JOIN   certification_applications ca ON ca.application_id = ce.application_id
JOIN   farms fm   ON fm.farm_id = ca.farm_id
JOIN   farmers fr ON fr.farmer_id = fm.farmer_id
WHERE  ce.certificate_status = 'ACTIVE'
AND    ce.expiry_date BETWEEN TRUNC(SYSDATE) AND TRUNC(SYSDATE) + 90
ORDER  BY ce.expiry_date;

-- Q15. Date-based: applications submitted in the last 30 days.
-- EXPECTED OUTPUT (SIMULATED): applications 6, 7, 8 and 10.
SELECT application_id, farm_id, application_date, status
FROM   certification_applications
WHERE  application_date >= TRUNC(SYSDATE) - 30
ORDER  BY application_date;

-- Q16. Average compliance score given by each inspector (JOIN-free aggregate).
-- EXPECTED OUTPUT (SIMULATED): Dr. P. S. Mehta 84.63 (2); A. K. Joshi 80 (3); N. R. Trivedi 66 (2).
SELECT inspector_name, COUNT(*) AS inspections_done,
       ROUND(AVG(compliance_score), 2) AS avg_score
FROM   inspections
GROUP  BY inspector_name
ORDER  BY avg_score DESC;

-- Q17. UPDATE that is safe for referential integrity: change a farmer contact (only a non-key column).
-- EXPECTED OUTPUT (SIMULATED): 1 row updated.
UPDATE farmers
SET    phone = '9427567891',
       address = 'Station Road, Nadiad, Kheda, Gujarat'
WHERE  farmer_id = 6;
SELECT farmer_id, farmer_name, phone, address FROM farmers WHERE farmer_id = 6;
COMMIT;

-- Q18. DELETE that is safe for referential integrity.
-- A temporary farmer (explicit ID 999, no farms) is inserted, then deleted.
-- The NOT EXISTS guard guarantees we only delete a farmer with no child rows.
-- EXPECTED OUTPUT (SIMULATED): 1 row inserted, 1 row deleted, then 0 rows found.
INSERT INTO farmers (farmer_id, farmer_name, phone, address)
VALUES (999, 'Temporary Demo Farmer', '9000000000', 'Demo Address, Anand');
DELETE FROM farmers f
WHERE  f.farmer_id = 999
AND    NOT EXISTS (SELECT 1 FROM farms fm WHERE fm.farmer_id = f.farmer_id);
SELECT COUNT(*) AS rows_left_for_999 FROM farmers WHERE farmer_id = 999;
COMMIT;

/* =====================================================================
   SECTION 6 OF 13 : VIEWS
   ===================================================================== */

-- View 1: farmer + farm + application + certificate in one place.
-- LEFT JOINs keep farmers/farms that have no application or certificate yet.
CREATE OR REPLACE VIEW v_farmer_certification_info AS
SELECT fr.farmer_id, fr.farmer_name, fr.phone,
       fm.farm_id, fm.farm_name, fm.location, fm.area_acres,
       ca.application_id, ca.application_date,
       ca.status AS application_status, ca.requested_cert_type,
       ce.certificate_number, ce.issue_date, ce.expiry_date, ce.certificate_status
FROM   farmers fr
LEFT JOIN farms fm ON fm.farmer_id = fr.farmer_id
LEFT JOIN certification_applications ca ON ca.farm_id = fm.farm_id
LEFT JOIN certificates ce ON ce.application_id = ca.application_id;

-- View 2: expired certificates and certificates expiring within 90 days.
-- The category is computed from expiry_date (not the stored status), so the view
-- is correct even if no row has been updated since a certificate lapsed.
CREATE OR REPLACE VIEW v_expiring_certificates AS
SELECT ce.certificate_id, ce.certificate_number,
       fr.farmer_name, fr.phone, fm.farm_name, ce.expiry_date,
       TRUNC(ce.expiry_date) - TRUNC(SYSDATE) AS days_remaining,
       CASE WHEN ce.expiry_date < TRUNC(SYSDATE) THEN 'EXPIRED'
            ELSE 'EXPIRING SOON' END AS expiry_category
FROM   certificates ce
JOIN   certification_applications ca ON ca.application_id = ce.application_id
JOIN   farms fm   ON fm.farm_id = ca.farm_id
JOIN   farmers fr ON fr.farmer_id = fm.farmer_id
WHERE  ce.certificate_status IN ('ACTIVE','EXPIRED')
AND    ce.expiry_date <= TRUNC(SYSDATE) + 90;

-- Demonstration of View 1 (all of Ramesh Patel's rows).
-- EXPECTED OUTPUT (SIMULATED):
--   Ramesh Patel | Patel Organic Fields | 1 | APPROVED         | GJ-ORG-0001 | EXPIRED
--   Ramesh Patel | Patel Organic Fields | 7 | UNDER_INSPECTION | (null)      | (null)
--   Ramesh Patel | Patel Millet Plot    | 6 | PENDING          | (null)      | (null)
SELECT farmer_name, farm_name, application_id, application_status,
       certificate_number, certificate_status
FROM   v_farmer_certification_info
WHERE  farmer_id = 1
ORDER  BY farm_id, application_id;

-- Demonstration of View 2.
-- EXPECTED OUTPUT (SIMULATED):
--   GJ-ORG-0001 | Ramesh Patel    | Patel Organic Fields  | 25-SEP-2026 | -35 | EXPIRED
--   GJ-ORG-0002 | Sunita Desai    | Desai Green Acres     | 19-NOV-2026 |  20 | EXPIRING SOON
--   GJ-ORG-0005 | Harshad Chauhan | Chauhan Mango Orchard | 24-DEC-2026 |  55 | EXPIRING SOON
SELECT certificate_number, farmer_name, farm_name, expiry_date, days_remaining, expiry_category
FROM   v_expiring_certificates
ORDER  BY expiry_date;

/* =====================================================================
   SECTION 7 OF 13 : STORED PROCEDURES
   The procedures do NOT commit. The caller decides when to COMMIT or
   ROLLBACK, which lets the demonstrations below undo their changes.
   Error codes used (user-defined, range -20000 to -20999):
     -20010 farm not found          -20011 farm already has an open application
     -20012 invalid certification type
     -20020 application not found   -20021 application cannot be inspected
     -20022 invalid compliance score
   ===================================================================== */

-- Procedure 1: submit a certification application.
-- IN  p_farm_id   : farm that is applying
-- IN  p_cert_type : NPOP, NOP-USDA, PGS-INDIA or ORGANIC-EU
-- OUT p_application_id : ID of the new application
CREATE OR REPLACE PROCEDURE sp_submit_application (
  p_farm_id        IN  NUMBER,
  p_cert_type      IN  VARCHAR2,
  p_application_id OUT NUMBER
) IS
  v_farm_name          farms.farm_name%TYPE;
  v_open_count         NUMBER;
  v_type               VARCHAR2(20) := UPPER(TRIM(p_cert_type));
  e_open_application   EXCEPTION;
  e_bad_type           EXCEPTION;
BEGIN
  IF v_type IS NULL OR v_type NOT IN ('NPOP','NOP-USDA','PGS-INDIA','ORGANIC-EU') THEN
    RAISE e_bad_type;
  END IF;

  SELECT farm_name INTO v_farm_name FROM farms WHERE farm_id = p_farm_id;

  SELECT COUNT(*) INTO v_open_count
  FROM   certification_applications
  WHERE  farm_id = p_farm_id AND status IN ('PENDING','UNDER_INSPECTION');
  IF v_open_count > 0 THEN
    RAISE e_open_application;
  END IF;

  p_application_id := seq_application.NEXTVAL;
  INSERT INTO certification_applications
         (application_id, farm_id, application_date, status, requested_cert_type)
  VALUES (p_application_id, p_farm_id, SYSDATE, 'PENDING', v_type);

  DBMS_OUTPUT.PUT_LINE('Application ' || p_application_id || ' submitted for farm '
                       || v_farm_name || ' (' || v_type || ').');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20010, 'Farm ' || p_farm_id || ' does not exist.');
  WHEN e_open_application THEN
    RAISE_APPLICATION_ERROR(-20011, 'Farm ' || p_farm_id
         || ' already has an open application (PENDING or UNDER_INSPECTION).');
  WHEN e_bad_type THEN
    RAISE_APPLICATION_ERROR(-20012, 'Invalid certification type: ' || p_cert_type
         || '. Use NPOP, NOP-USDA, PGS-INDIA or ORGANIC-EU.');
END sp_submit_application;
/

-- Procedure 2: record an inspection and update the application status.
-- Rule:  score >= 75  -> PASS         -> application APPROVED
--        50 to 74.99  -> CONDITIONAL  -> application stays UNDER_INSPECTION
--        score < 50   -> FAIL         -> application REJECTED
CREATE OR REPLACE PROCEDURE sp_record_inspection (
  p_application_id   IN NUMBER,
  p_inspector_name   IN VARCHAR2,
  p_findings         IN VARCHAR2,
  p_compliance_score IN NUMBER,
  p_inspection_date  IN DATE DEFAULT SYSDATE
) IS
  v_status             certification_applications.status%TYPE;
  v_result             inspections.result%TYPE;
  v_new_status         certification_applications.status%TYPE;
  e_not_inspectable    EXCEPTION;
  e_bad_score          EXCEPTION;
BEGIN
  IF p_compliance_score IS NULL OR p_compliance_score < 0 OR p_compliance_score > 100 THEN
    RAISE e_bad_score;
  END IF;

  SELECT status INTO v_status
  FROM   certification_applications
  WHERE  application_id = p_application_id;

  IF v_status NOT IN ('PENDING','UNDER_INSPECTION') THEN
    RAISE e_not_inspectable;
  END IF;

  IF p_compliance_score >= 75 THEN
    v_result := 'PASS';         v_new_status := 'APPROVED';
  ELSIF p_compliance_score >= 50 THEN
    v_result := 'CONDITIONAL';  v_new_status := 'UNDER_INSPECTION';
  ELSE
    v_result := 'FAIL';         v_new_status := 'REJECTED';
  END IF;

  INSERT INTO inspections
         (inspection_id, application_id, inspector_name, inspection_date,
          findings, compliance_score, result)
  VALUES (seq_inspection.NEXTVAL, p_application_id, p_inspector_name,
          p_inspection_date, p_findings, p_compliance_score, v_result);

  UPDATE certification_applications
  SET    status = v_new_status
  WHERE  application_id = p_application_id;

  DBMS_OUTPUT.PUT_LINE('Inspection recorded for application ' || p_application_id
       || ': score ' || p_compliance_score || ' -> ' || v_result
       || '. Application status set to ' || v_new_status || '.');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20020, 'Application ' || p_application_id || ' does not exist.');
  WHEN e_not_inspectable THEN
    RAISE_APPLICATION_ERROR(-20021, 'Application ' || p_application_id || ' is already '
         || v_status || ' and cannot be inspected again.');
  WHEN e_bad_score THEN
    RAISE_APPLICATION_ERROR(-20022, 'Compliance score must be between 0 and 100.');
END sp_record_inspection;
/

-- ---- Test calls for Section 7 (changes are rolled back at the end) ----
-- Test 7a: submit an application for farm 7 (Desai Vegetable Plot, no open application).
-- EXPECTED OUTPUT (SIMULATED):
--   Application 11 submitted for farm Desai Vegetable Plot (NPOP).
--   Returned application ID: 11
DECLARE
  v_app_id NUMBER;
BEGIN
  sp_submit_application(7, 'npop', v_app_id);
  DBMS_OUTPUT.PUT_LINE('Returned application ID: ' || v_app_id);
END;
/

-- Test 7b: record a passing inspection for pending application 6.
-- EXPECTED OUTPUT (SIMULATED):
--   Inspection recorded for application 6: score 78 -> PASS. Application status set to APPROVED.
BEGIN
  sp_record_inspection(6, 'N. R. Trivedi', 'All organic practices verified; records complete.', 78);
END;
/

-- Check the uncommitted changes, then undo them.
-- EXPECTED OUTPUT (SIMULATED): application 6 APPROVED, application 11 PENDING.
SELECT application_id, farm_id, status FROM certification_applications WHERE application_id IN (6, 11) ORDER BY application_id;
ROLLBACK;
-- EXPECTED OUTPUT (SIMULATED) after rollback: application 6 PENDING, application 11 no longer exists.
SELECT application_id, farm_id, status FROM certification_applications WHERE application_id IN (6, 11) ORDER BY application_id;

-- Test 7c: error cases (messages are caught and printed).
-- EXPECTED OUTPUT (SIMULATED):
--   Farm check : ORA-20010: Farm 9999 does not exist.
--   Open app   : ORA-20011: Farm 1 already has an open application (PENDING or UNDER_INSPECTION).
--   Re-inspect : ORA-20021: Application 1 is already APPROVED and cannot be inspected again.
DECLARE
  v_app_id NUMBER;
BEGIN
  BEGIN
    sp_submit_application(9999, 'NPOP', v_app_id);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Farm check : ' || SQLERRM);
  END;
  BEGIN
    sp_submit_application(1, 'NPOP', v_app_id);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Open app   : ' || SQLERRM);
  END;
  BEGIN
    sp_record_inspection(1, 'A. K. Joshi', 'Repeat visit', 80);
  EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Re-inspect : ' || SQLERRM);
  END;
END;
/

/* =====================================================================
   SECTION 8 OF 13 : FUNCTIONS
   ===================================================================== */

-- Function 1: days remaining before a certificate expires.
-- Returns a negative number if the certificate has already expired.
CREATE OR REPLACE FUNCTION fn_days_to_expiry (p_certificate_id IN NUMBER)
RETURN NUMBER
IS
  v_expiry certificates.expiry_date%TYPE;
BEGIN
  SELECT expiry_date INTO v_expiry
  FROM   certificates
  WHERE  certificate_id = p_certificate_id;
  RETURN TRUNC(v_expiry) - TRUNC(SYSDATE);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20030, 'Certificate ' || p_certificate_id || ' does not exist.');
END fn_days_to_expiry;
/

-- Function 2: average compliance score of all inspections of a farm.
-- Returns NULL when the farm exists but has never been inspected.
CREATE OR REPLACE FUNCTION fn_avg_compliance_score (p_farm_id IN NUMBER)
RETURN NUMBER
IS
  v_farm_count NUMBER;
  v_avg        NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_farm_count FROM farms WHERE farm_id = p_farm_id;
  IF v_farm_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20031, 'Farm ' || p_farm_id || ' does not exist.');
  END IF;

  SELECT ROUND(AVG(i.compliance_score), 2) INTO v_avg
  FROM   inspections i
  JOIN   certification_applications a ON a.application_id = i.application_id
  WHERE  a.farm_id = p_farm_id;

  RETURN v_avg;
END fn_avg_compliance_score;
/

-- Execution example 1: days to expiry for every certificate.
-- EXPECTED OUTPUT (SIMULATED, run on 30-OCT-2026): cert 1 = -35 (expired), 2 = 20, 3 = 165, 4 = 265, 5 = 55.
SELECT certificate_id, certificate_number, expiry_date,
       fn_days_to_expiry(certificate_id) AS days_remaining
FROM   certificates
ORDER  BY certificate_id;

-- Execution example 2: average compliance score for every farm (function used inside SQL).
-- EXPECTED OUTPUT (SIMULATED): farm1 77.25; farm2 NULL; farm3 88; farm4 85.5; farm5 66; farm6 81.25; farm7 NULL.
SELECT farm_id, farm_name, fn_avg_compliance_score(farm_id) AS avg_score
FROM   farms
ORDER  BY farm_id;

-- Execution example 3: calling the functions from PL/SQL, including an error case.
-- EXPECTED OUTPUT (SIMULATED):
--   Days left for certificate 2 : 20
--   Days left for certificate 1 : -35 (already expired)
--   Average score, farm 1       : 77.25
--   Average score, farm 2       : no inspections yet
--   Error: ORA-20031: Farm 9999 does not exist.
DECLARE
  v_days NUMBER;
  v_avg  NUMBER;
BEGIN
  v_days := fn_days_to_expiry(2);
  DBMS_OUTPUT.PUT_LINE('Days left for certificate 2 : ' || v_days);
  v_days := fn_days_to_expiry(1);
  DBMS_OUTPUT.PUT_LINE('Days left for certificate 1 : ' || v_days ||
                       CASE WHEN v_days < 0 THEN ' (already expired)' ELSE '' END);
  v_avg := fn_avg_compliance_score(1);
  DBMS_OUTPUT.PUT_LINE('Average score, farm 1       : ' || NVL(TO_CHAR(v_avg), 'no inspections yet'));
  v_avg := fn_avg_compliance_score(2);
  DBMS_OUTPUT.PUT_LINE('Average score, farm 2       : ' || NVL(TO_CHAR(v_avg), 'no inspections yet'));
  v_avg := fn_avg_compliance_score(9999);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

/* =====================================================================
   SECTION 9 OF 13 : CURSOR DEMONSTRATION
   Explicit cursor listing all PENDING applications with farm details.
   ===================================================================== */
SET SERVEROUTPUT ON SIZE UNLIMITED;

-- EXPECTED OUTPUT (SIMULATED, run on 30-OCT-2026):
--   ===== PENDING CERTIFICATION APPLICATIONS =====
--   Application ID : 6 | Applied on: 10-OCT-2026 | Type: PGS-INDIA
--      Farm: Patel Millet Plot, Vadtal, Anand (4.00 acres) | Farmer: Ramesh Patel
--   Application ID : 8 | Applied on: 25-OCT-2026 | Type: NOP-USDA
--      Farm: Chauhan Mango Orchard, Umreth, Anand (20.00 acres) | Farmer: Harshad Chauhan
--   Application ID : 10 | Applied on: 27-OCT-2026 | Type: NOP-USDA
--      Farm: Desai Green Acres, Borsad, Anand (8.75 acres) | Farmer: Sunita Desai
--   Total pending applications: 3
DECLARE
  CURSOR c_pending IS
    SELECT ca.application_id, ca.application_date, ca.requested_cert_type,
           fm.farm_name, fm.location, fm.area_acres, fr.farmer_name
    FROM   certification_applications ca
    JOIN   farms fm   ON fm.farm_id = ca.farm_id
    JOIN   farmers fr ON fr.farmer_id = fm.farmer_id
    WHERE  ca.status = 'PENDING'
    ORDER  BY ca.application_date, ca.application_id;

  r_app    c_pending%ROWTYPE;
  v_count  NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('===== PENDING CERTIFICATION APPLICATIONS =====');
  OPEN c_pending;
  LOOP
    FETCH c_pending INTO r_app;
    EXIT WHEN c_pending%NOTFOUND;
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE('Application ID : ' || r_app.application_id
        || ' | Applied on: ' || TO_CHAR(r_app.application_date, 'DD-MON-YYYY')
        || ' | Type: ' || r_app.requested_cert_type);
    DBMS_OUTPUT.PUT_LINE('   Farm: ' || r_app.farm_name || ', ' || r_app.location
        || ' (' || TO_CHAR(r_app.area_acres, 'FM990.00') || ' acres)'
        || ' | Farmer: ' || r_app.farmer_name);
  END LOOP;
  CLOSE c_pending;

  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('No pending applications found.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Total pending applications: ' || v_count);
  END IF;
END;
/

/* =====================================================================
   SECTION 10 OF 13 : TRIGGER
   trg_cert_validate  (BEFORE INSERT OR UPDATE, row level, on CERTIFICATES)
   Purpose 1: a certificate may only be issued for an APPROVED application.
   Purpose 2: a certificate whose expiry date has passed is stored as EXPIRED.
   No mutating-table error: the trigger fires on CERTIFICATES but only READS
   CERTIFICATION_APPLICATIONS (a different table), and changes only the row
   being processed (:NEW), never CERTIFICATES itself.
   ===================================================================== */
CREATE OR REPLACE TRIGGER trg_cert_validate
BEFORE INSERT OR UPDATE ON certificates
FOR EACH ROW
DECLARE
  v_app_status certification_applications.status%TYPE;
BEGIN
  -- Approval check: only on insert, or when the application link is changed.
  IF INSERTING OR UPDATING('APPLICATION_ID') THEN
    BEGIN
      SELECT status INTO v_app_status
      FROM   certification_applications
      WHERE  application_id = :NEW.application_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Certificate cannot be issued: application '
             || :NEW.application_id || ' does not exist.');
    END;
    IF v_app_status <> 'APPROVED' THEN
      RAISE_APPLICATION_ERROR(-20002, 'Certificate cannot be issued: application '
           || :NEW.application_id || ' has status ' || v_app_status
           || '; only APPROVED applications are eligible.');
    END IF;
  END IF;

  -- Auto-expiry: an ACTIVE certificate with a past expiry date becomes EXPIRED.
  IF :NEW.certificate_status = 'ACTIVE' AND :NEW.expiry_date < TRUNC(SYSDATE) THEN
    :NEW.certificate_status := 'EXPIRED';
  END IF;
END trg_cert_validate;
/

-- Trigger test 10a: block a certificate for an unapproved (PENDING) application 6.
-- EXPECTED OUTPUT (SIMULATED):
--   Blocked: ORA-20002: Certificate cannot be issued: application 6 has status PENDING; only APPROVED applications are eligible.
DECLARE
  e_unapproved EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_unapproved, -20002);
BEGIN
  INSERT INTO certificates (certificate_id, application_id, certificate_number, issue_date, expiry_date)
  VALUES (994, 6, 'GJ-ORG-TEST1', TRUNC(SYSDATE), TRUNC(SYSDATE) + 365);
  DBMS_OUTPUT.PUT_LINE('Unexpected: insert succeeded.');
  ROLLBACK;
EXCEPTION
  WHEN e_unapproved THEN
    DBMS_OUTPUT.PUT_LINE('Blocked: ' || SQLERRM);
    ROLLBACK;
END;
/

-- Trigger test 10b: pushing an expiry date into the past flips the status to EXPIRED automatically.
-- EXPECTED OUTPUT (SIMULATED):
--   after UPDATE  : certificate 3 -> status EXPIRED
--   after ROLLBACK: certificate 3 -> status ACTIVE (original expiry restored)
UPDATE certificates SET expiry_date = TRUNC(SYSDATE) - 1 WHERE certificate_id = 3;
SELECT certificate_id, certificate_number, expiry_date, certificate_status FROM certificates WHERE certificate_id = 3;
ROLLBACK;
SELECT certificate_id, certificate_number, expiry_date, certificate_status FROM certificates WHERE certificate_id = 3;

/* =====================================================================
   SECTION 11 OF 13 : EXCEPTION-HANDLING DEMONSTRATIONS
   ===================================================================== */

-- 11.1 NO_DATA_FOUND : SELECT INTO finds no row.
-- EXPECTED OUTPUT (SIMULATED): NO_DATA_FOUND handled: no farmer exists with ID 9999.
DECLARE
  v_name farmers.farmer_name%TYPE;
BEGIN
  SELECT farmer_name INTO v_name FROM farmers WHERE farmer_id = 9999;
  DBMS_OUTPUT.PUT_LINE('Farmer: ' || v_name);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('NO_DATA_FOUND handled: no farmer exists with ID 9999.');
END;
/

-- 11.2 DUP_VAL_ON_INDEX : phone 9825012345 already belongs to Ramesh Patel (UNIQUE constraint).
-- Explicit ID 998 is used so no sequence number is consumed.
-- EXPECTED OUTPUT (SIMULATED): DUP_VAL_ON_INDEX handled: ORA-00001: unique constraint (YOURSCHEMA.UQ_FARMERS_PHONE) violated
DECLARE
  v_dummy NUMBER;
BEGIN
  INSERT INTO farmers (farmer_id, farmer_name, phone, address)
  VALUES (998, 'Duplicate Phone Farmer', '9825012345', 'Anand, Gujarat');
  DBMS_OUTPUT.PUT_LINE('Unexpected: insert succeeded.');
  ROLLBACK;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('DUP_VAL_ON_INDEX handled: ' || SQLERRM);
    ROLLBACK;
END;
/

-- 11.3 Custom exception for an invalid certification operation:
-- trying to issue a certificate for an application that is not APPROVED.
-- EXPECTED OUTPUT (SIMULATED): Invalid certification operation: application 6 is PENDING, not APPROVED.
DECLARE
  e_invalid_cert_operation EXCEPTION;
  v_app_id  NUMBER := 6;
  v_status  certification_applications.status%TYPE;
BEGIN
  SELECT status INTO v_status
  FROM   certification_applications
  WHERE  application_id = v_app_id;

  IF v_status <> 'APPROVED' THEN
    RAISE e_invalid_cert_operation;
  END IF;
  DBMS_OUTPUT.PUT_LINE('Application ' || v_app_id || ' is approved; certificate may be issued.');
EXCEPTION
  WHEN e_invalid_cert_operation THEN
    DBMS_OUTPUT.PUT_LINE('Invalid certification operation: application ' || v_app_id
                         || ' is ' || v_status || ', not APPROVED.');
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Application ' || v_app_id || ' does not exist.');
END;
/

-- 11.4 Mapping an application error code (-20011) from a procedure to a named exception.
-- EXPECTED OUTPUT (SIMULATED): Caught: ORA-20011: Farm 1 already has an open application (PENDING or UNDER_INSPECTION).
DECLARE
  e_open_application EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_open_application, -20011);
  v_app_id NUMBER;
BEGIN
  sp_submit_application(1, 'NPOP', v_app_id);
EXCEPTION
  WHEN e_open_application THEN
    DBMS_OUTPUT.PUT_LINE('Caught: ' || SQLERRM);
END;
/

/* =====================================================================
   SECTION 12 OF 13 : TEST CASES (T1 - T10, plus T8b)
   Run in order, once. IDs below assume a fresh run of this whole script:
   farmer 7, farm 8, application 12 (11 was used and rolled back in Test 7a),
   inspection 9 (8 was used and rolled back in Test 7b), certificate 6.
   Every "EXPECTED OUTPUT (SIMULATED)" is hand-derived, not machine output.
   ===================================================================== */

-- T1. Valid farmer registration.
-- EXPECTED OUTPUT (SIMULATED): 1 row: 7 | Dinesh Vaghela | 9876501234
INSERT INTO farmers (farmer_id, farmer_name, phone, email, address)
VALUES (seq_farmer.NEXTVAL, 'Dinesh Vaghela', '9876501234', 'dinesh.vaghela@example.com', 'Sojitra, Anand, Gujarat');
COMMIT;
SELECT farmer_id, farmer_name, phone FROM farmers WHERE phone = '9876501234';

-- T2. Valid farm registration (farmer found through the unique phone number).
-- EXPECTED OUTPUT (SIMULATED): 1 row: 8 | Vaghela Natural Farm | 9 | Loamy
INSERT INTO farms (farm_id, farmer_id, farm_name, location, area_acres, soil_type)
VALUES (seq_farm.NEXTVAL, (SELECT farmer_id FROM farmers WHERE phone = '9876501234'),
        'Vaghela Natural Farm', 'Sojitra, Anand', 9.00, 'Loamy');
COMMIT;
SELECT farm_id, farm_name, area_acres, soil_type FROM farms WHERE farm_name = 'Vaghela Natural Farm';

-- T3. Application submission through the stored procedure.
-- EXPECTED OUTPUT (SIMULATED):
--   Application 12 submitted for farm Vaghela Natural Farm (NPOP).
--   Application ID returned: 12
DECLARE
  v_farm_id farms.farm_id%TYPE;
  v_app_id  NUMBER;
BEGIN
  SELECT farm_id INTO v_farm_id FROM farms WHERE farm_name = 'Vaghela Natural Farm';
  sp_submit_application(v_farm_id, 'NPOP', v_app_id);
  DBMS_OUTPUT.PUT_LINE('Application ID returned: ' || v_app_id);
  COMMIT;
END;
/

-- T4. Inspection recording (score 88 means PASS, which approves the application).
-- EXPECTED OUTPUT (SIMULATED):
--   Inspection recorded for application 12: score 88 -> PASS. Application status set to APPROVED.
DECLARE
  v_app_id certification_applications.application_id%TYPE;
BEGIN
  SELECT ca.application_id INTO v_app_id
  FROM   certification_applications ca
  JOIN   farms fm ON fm.farm_id = ca.farm_id
  WHERE  fm.farm_name = 'Vaghela Natural Farm';
  sp_record_inspection(v_app_id, 'Dr. P. S. Mehta', 'Organic practices verified; records complete.', 88);
  COMMIT;
END;
/

-- T5. Application approval confirmed (the procedure in T4 changed the status).
-- EXPECTED OUTPUT (SIMULATED): application 12 | APPROVED ; inspection 9 | 88 | PASS
SELECT ca.application_id, ca.status, i.inspection_id, i.compliance_score, i.result
FROM   certification_applications ca
JOIN   farms fm ON fm.farm_id = ca.farm_id
JOIN   inspections i ON i.application_id = ca.application_id
WHERE  fm.farm_name = 'Vaghela Natural Farm';

-- T6. Certificate issuance for the approved application.
-- EXPECTED OUTPUT (SIMULATED, run on 30-OCT-2026): GJ-ORG-0006 | ACTIVE | 365 days remaining
INSERT INTO certificates (certificate_id, application_id, certificate_number, issue_date, expiry_date)
VALUES (seq_certificate.NEXTVAL,
        (SELECT ca.application_id FROM certification_applications ca
         JOIN farms fm ON fm.farm_id = ca.farm_id
         WHERE fm.farm_name = 'Vaghela Natural Farm'),
        'GJ-ORG-0006', TRUNC(SYSDATE), ADD_MONTHS(TRUNC(SYSDATE), 12));
COMMIT;
SELECT certificate_id, certificate_number, certificate_status,
       fn_days_to_expiry(certificate_id) AS days_remaining
FROM   certificates
WHERE  certificate_number = 'GJ-ORG-0006';

-- T7. Expired certificate detection (view + stored status set by trigger/update).
-- EXPECTED OUTPUT (SIMULATED): GJ-ORG-0001 | Patel Organic Fields | -35 | EXPIRED (status column also EXPIRED)
SELECT certificate_number, farm_name, days_remaining, expiry_category
FROM   v_expiring_certificates
WHERE  expiry_category = 'EXPIRED';
SELECT certificate_number, certificate_status FROM certificates WHERE expiry_date < TRUNC(SYSDATE);

-- T8. Invalid foreign key: farm for a farmer that does not exist.
-- EXPECTED OUTPUT (SIMULATED): Test 8 rejected: ORA-02291: integrity constraint (YOURSCHEMA.FK_FARMS_FARMER) violated - parent key not found
DECLARE
  e_parent_missing EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_parent_missing, -2291);
BEGIN
  INSERT INTO farms (farm_id, farmer_id, farm_name, location, area_acres, soil_type)
  VALUES (997, 9999, 'Ghost Farm', 'Unknown', 5, 'Loamy');
  DBMS_OUTPUT.PUT_LINE('Unexpected: insert succeeded.');
  ROLLBACK;
EXCEPTION
  WHEN e_parent_missing THEN
    DBMS_OUTPUT.PUT_LINE('Test 8 rejected: ' || SQLERRM);
    ROLLBACK;
END;
/

-- T8b (bonus). Referential integrity in the other direction: delete a farmer who owns farms.
-- EXPECTED OUTPUT (SIMULATED): Test 8b rejected: ORA-02292: integrity constraint (YOURSCHEMA.FK_FARMS_FARMER) violated - child record found
DECLARE
  e_child_found EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_child_found, -2292);
BEGIN
  DELETE FROM farmers WHERE farmer_id = 1;
  DBMS_OUTPUT.PUT_LINE('Unexpected: delete succeeded.');
  ROLLBACK;
EXCEPTION
  WHEN e_child_found THEN
    DBMS_OUTPUT.PUT_LINE('Test 8b rejected: ' || SQLERRM);
    ROLLBACK;
END;
/

-- T9. Duplicate certificate number.
-- A temporary APPROVED application (ID 996) is created so ONLY the certificate-number rule can fail.
-- EXPECTED OUTPUT (SIMULATED): Test 9 rejected: ORA-00001: unique constraint (YOURSCHEMA.UQ_CERT_NUMBER) violated
BEGIN
  INSERT INTO certification_applications (application_id, farm_id, application_date, status, requested_cert_type)
  VALUES (996, 4, TRUNC(SYSDATE) - 10, 'APPROVED', 'NPOP');
  INSERT INTO certificates (certificate_id, application_id, certificate_number, issue_date, expiry_date)
  VALUES (995, 996, 'GJ-ORG-0001', TRUNC(SYSDATE), TRUNC(SYSDATE) + 365);
  DBMS_OUTPUT.PUT_LINE('Unexpected: insert succeeded.');
  ROLLBACK;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('Test 9 rejected: ' || SQLERRM);
    ROLLBACK;
END;
/

-- T10. Certificate for an unapproved application (application 6 is PENDING).
-- EXPECTED OUTPUT (SIMULATED): Test 10 rejected: ORA-20002: Certificate cannot be issued: application 6 has status PENDING; only APPROVED applications are eligible.
DECLARE
  e_unapproved EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_unapproved, -20002);
BEGIN
  INSERT INTO certificates (certificate_id, application_id, certificate_number, issue_date, expiry_date)
  VALUES (993, 6, 'GJ-ORG-0099', TRUNC(SYSDATE), TRUNC(SYSDATE) + 365);
  DBMS_OUTPUT.PUT_LINE('Unexpected: insert succeeded.');
  ROLLBACK;
EXCEPTION
  WHEN e_unapproved THEN
    DBMS_OUTPUT.PUT_LINE('Test 10 rejected: ' || SQLERRM);
    ROLLBACK;
END;
/

/* =====================================================================
   SECTION 13 OF 13 : VERIFICATION QUERIES
   ===================================================================== */

-- V1. Row counts.
-- EXPECTED OUTPUT (SIMULATED, after a single full run): FARMERS 7; FARMS 8; CERTIFICATION_APPLICATIONS 11; INSPECTIONS 8; CERTIFICATES 6.
SELECT 'FARMERS' AS table_name, COUNT(*) AS row_count FROM farmers
UNION ALL SELECT 'FARMS', COUNT(*) FROM farms
UNION ALL SELECT 'CERTIFICATION_APPLICATIONS', COUNT(*) FROM certification_applications
UNION ALL SELECT 'INSPECTIONS', COUNT(*) FROM inspections
UNION ALL SELECT 'CERTIFICATES', COUNT(*) FROM certificates;

-- V2. Orphan check (referential integrity). EXPECTED OUTPUT (SIMULATED): all four counts are 0.
SELECT 'farms without farmer' AS check_name, COUNT(*) AS orphans
FROM farms f WHERE NOT EXISTS (SELECT 1 FROM farmers fr WHERE fr.farmer_id = f.farmer_id)
UNION ALL
SELECT 'applications without farm', COUNT(*)
FROM certification_applications a WHERE NOT EXISTS (SELECT 1 FROM farms f WHERE f.farm_id = a.farm_id)
UNION ALL
SELECT 'inspections without application', COUNT(*)
FROM inspections i WHERE NOT EXISTS (SELECT 1 FROM certification_applications a WHERE a.application_id = i.application_id)
UNION ALL
SELECT 'certificates without application', COUNT(*)
FROM certificates c WHERE NOT EXISTS (SELECT 1 FROM certification_applications a WHERE a.application_id = c.application_id);

-- V3. All project objects and their status. EXPECTED OUTPUT (SIMULATED): every STATUS = VALID.
SELECT object_type, object_name, status
FROM   user_objects
WHERE  object_type IN ('TABLE','VIEW','SEQUENCE','PROCEDURE','FUNCTION','TRIGGER')
AND    object_name IN ('FARMERS','FARMS','CERTIFICATION_APPLICATIONS','INSPECTIONS','CERTIFICATES',
                       'V_FARMER_CERTIFICATION_INFO','V_EXPIRING_CERTIFICATES',
                       'SEQ_FARMER','SEQ_FARM','SEQ_APPLICATION','SEQ_INSPECTION','SEQ_CERTIFICATE',
                       'SP_SUBMIT_APPLICATION','SP_RECORD_INSPECTION',
                       'FN_DAYS_TO_EXPIRY','FN_AVG_COMPLIANCE_SCORE','TRG_CERT_VALIDATE')
ORDER  BY object_type, object_name;

-- V4. Invalid objects. EXPECTED OUTPUT (SIMULATED): no rows selected.
SELECT object_name, object_type, status FROM user_objects WHERE status = 'INVALID';

-- V5. Keys defined on the tables (P = primary, R = foreign, U = unique).
-- EXPECTED OUTPUT (SIMULATED): 5 primary keys, 4 foreign keys, 5 unique constraints.
SELECT table_name, constraint_name, constraint_type
FROM   user_constraints
WHERE  table_name IN ('FARMERS','FARMS','CERTIFICATION_APPLICATIONS','INSPECTIONS','CERTIFICATES')
AND    constraint_type IN ('P','R','U')
ORDER  BY table_name, constraint_type, constraint_name;

-- V6. Final status summary of certificates. EXPECTED OUTPUT (SIMULATED): ACTIVE 5; EXPIRED 1.
SELECT certificate_status, COUNT(*) AS total FROM certificates GROUP BY certificate_status ORDER BY certificate_status;

COMMIT;

/* ============================ END OF SCRIPT ============================ */
