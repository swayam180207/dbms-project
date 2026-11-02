# Demonstration Guide: Organic Farming Certification Management System

Total time: about 10 minutes. Use SQL Developer with **View > Dbms Output** open.

## Before you start (2 minutes, do this earlier)
1. Connect to your Oracle schema.
2. Open `Organic_Farming_Certification.sql` and click **Run Script (F5)** once. Wait until it finishes.
3. Keep the script open so you can run single sections (select the text, press F5).
4. Open `ER_Diagram.mmd` in https://mermaid.live and keep the picture ready.

Note: the script is re-runnable. If a demo changes the data too much, run it again from the top.

## Presentation flow

| Step | Time | What to show | What to say |
|---|---|---|---|
| 1 | 1 min | ER diagram | Five tables, four one-to-many style links. One application has many inspections and at most one certificate. |
| 2 | 1 min | Section 2 (CREATE TABLE) | Point out PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, DEFAULT and NOT NULL. |
| 3 | 1 min | Section 4 sample data | Dates are relative to SYSDATE, so expired and expiring data always stay correct. |
| 4 | 1 min | Q4 (LEFT JOIN), Q6 (HAVING), Q13 (expired), Q14 (renewals) | Run these four only; mention the other queries are in Section 5. |
| 5 | 1 min | Both views | `v_farmer_certification_info` is the all-in-one report; `v_expiring_certificates` is the renewal watch-list. |
| 6 | 2 min | Section 7 tests (7a, 7b, 7c) | Submit an application, record an inspection, show APPROVED, then ROLLBACK. Show the error messages. |
| 7 | 1 min | Section 8 functions | Days left for each certificate; average score per farm. |
| 8 | 1 min | Section 9 cursor | Pending applications printed one by one. |
| 9 | 1 min | Section 10 trigger test 10a and 10b | Unapproved application is blocked; past expiry flips status to EXPIRED. |
| 10 | 1 min | Section 12 tests T8, T9, T10 | Invalid foreign key, duplicate certificate number, unapproved application. |

## Questions to expect, and one-line answers
- *Why sequences?* They generate unique primary keys; they work on all Oracle versions.
- *Why do the procedures not COMMIT?* The caller controls the transaction, so it can ROLLBACK if something fails.
- *Why no mutating-table error?* The trigger reads a different table and only changes its own row (`:NEW`).
- *Why is the view category computed instead of using the status column?* A certificate can lapse without any row being updated, so the date is the reliable source.

## Honest notes to mention if asked
- The expected outputs in the comments and report are **simulated** (worked out by hand from the sample data). Compare them with your real screen.
- On a different day than 30-OCT-2026, dates and day counts will differ.
- IDs in Section 12 assume one full top-to-bottom run on a fresh schema.

## If something goes wrong
- *No output text?* Open View > Dbms Output and click the green plus to attach your connection.
- *ORA-00955 name already used?* Run Section 1 (cleanup) first.
- *Script stops halfway?* Fix the error shown in the Script Output tab, then run the whole file again.
