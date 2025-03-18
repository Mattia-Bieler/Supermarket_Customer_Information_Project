-- Imported marketing_data.csv into Excel to check the format of the date column.
-- Used Text to Column twice for Dt_Customer to handle the difference in date formats (DMY and MDY).
-- Changed the date format to YYYY-MM-DD to import file into pgAdmin4.

/********************************************************************************
Data Preparation: marketing_data.csv
********************************************************************************/
-- Create a 'marketing_data' table to store customer information.
CREATE TABLE marketing_data (
    id SERIAL PRIMARY KEY,
    year_birth INT,
    education VARCHAR(50),
    marital_status VARCHAR(50),
    income TEXT, -- Store as TEXT for now to handle the '$' sign.
    kidhome INT,
    teenhome INT,
    dt_customer DATE,
    recency INT,
    amtliq INT,
    amtvege INT,
    amtnonveg INT,
    amtpes INT,
    amtchocolates INT,
    amtcomm INT,
    numdeals INT,
    numwebbuy INT,
    numwalkinpur INT,
    numvisits INT,
    response INT,
    complain INT,
    country VARCHAR(50),
    count_success INT);

-- View the updated 'marketing_data' table.
SELECT * FROM marketing_data;

-- Alter column names for clarity.
ALTER TABLE marketing_data RENAME COLUMN dt_customer TO customer_reg;
ALTER TABLE marketing_data RENAME COLUMN amtliq TO amtalco;
ALTER TABLE marketing_data RENAME COLUMN amtnonveg TO amtmeat;
ALTER TABLE marketing_data RENAME COLUMN amtpes TO amtfish;
ALTER TABLE marketing_data RENAME COLUMN amtchocolates TO amtchoc;
ALTER TABLE marketing_data RENAME COLUMN numwalkinpur TO numwalkinbuy;
ALTER TABLE marketing_data RENAME COLUMN numvisits TO numwebvisits;

-- Remove '$', commas, and decimal part from the 'income' column in a single update statement.
UPDATE marketing_data
SET income = REPLACE(REPLACE(REPLACE(income, '$', ''), ',', ''), '.00', '');

-- Change the 'income' column data type to INTEGER.
ALTER TABLE marketing_data
    ALTER COLUMN income TYPE INT USING CAST(income AS INT);

-- Rename the 'income' column to 'income_$'.
ALTER TABLE marketing_data 
    RENAME COLUMN income TO income_$;

-- View the updated 'marketing_data' table.
SELECT * FROM marketing_data;

-- Check for duplicates in the 'id' column.
SELECT id, COUNT(*)
FROM marketing_data
GROUP BY id
HAVING COUNT(*) > 1;

-- Create a function to count NULL values for each column in a given table.
CREATE OR REPLACE FUNCTION nulls_count(target_table TEXT)
RETURNS TABLE(target_column TEXT, null_count BIGINT) AS
$$
DECLARE
    column_record RECORD;  -- Variable to hold column names from the table.
    query TEXT;  -- Variable to store dynamically constructed SQL query.
BEGIN
    -- Loop through each column in the specified table.
    FOR column_record IN 
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = target_table
    LOOP
        -- Construct SQL query to count NULL values for the current column.
        query := 'SELECT ' || quote_literal(column_record.column_name) || ', COUNT(*) 
                  FROM ' || quote_ident(target_table) || 
                 ' WHERE "' || column_record.column_name || '" IS NULL';
        -- Execute the constructed query and return the results.
        RETURN QUERY EXECUTE query;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Apply the nulls_count function to the 'marketing_data' table.
SELECT * FROM nulls_count('marketing_data');

-- Show all distinct values in the 'education' column.
SELECT DISTINCT education
FROM marketing_data
ORDER BY education;

-- Show all distinct values in the 'marital_status' column.
SELECT DISTINCT marital_status
FROM marketing_data
ORDER BY marital_status;

-- Remove rows where marital status is 'YOLO' or 'Absurd'.
DELETE FROM marketing_data
WHERE marital_status IN ('YOLO', 'Absurd');

-- Change marital status value 'Alone' to 'Single'.
UPDATE marketing_data
SET marital_status = 'Single'
WHERE marital_status = 'Alone';

-- Show all distinct values in the 'marital_status' column to check changes have been made.
SELECT DISTINCT marital_status
FROM marketing_data
ORDER BY marital_status;

-- Show all distinct values in the 'country' column.
SELECT DISTINCT country
FROM marketing_data
ORDER BY country;

-- Update the 'country' column with full country names.
UPDATE marketing_data
SET country = CASE country
    WHEN 'AUS' THEN 'Australia'
    WHEN 'CA' THEN 'Canada'
    WHEN 'GER' THEN 'Germany'
    WHEN 'IND' THEN 'India'
    WHEN 'ME' THEN 'Montenegro'
    WHEN 'SA' THEN 'South Africa'
    WHEN 'SP' THEN 'Spain'
    WHEN 'US' THEN 'United States'
    ELSE country -- If the country value is not in the list, leave it unchanged.
END;

-- Show all distinct values in the 'country' column.
SELECT DISTINCT country
FROM marketing_data
ORDER BY country;

-- Add an 'age' column to the 'marketing_data' table.
ALTER TABLE marketing_data
    ADD COLUMN age INT;

-- Update the 'age' column based on the 'year_birth' column.
UPDATE marketing_data
SET age = 2025 - year_birth;

-- Select 'id', 'year_birth', and 'age' columns to verify the update.
SELECT id, year_birth, age
FROM marketing_data;

-- Create a function to find integer outliers in a specified column of any table.
CREATE FUNCTION find_integer_outliers(
    target_table TEXT, 
    target_column TEXT
) 
RETURNS TABLE (
    primary_key INTEGER,   -- Primary key of the row.
    column_name TEXT,      -- Name of the column being checked.
    outlier_value INTEGER  -- Outlier value.
) 
LANGUAGE plpgsql AS $$
BEGIN
    -- Main query to find outliers.
    RETURN QUERY EXECUTE format(
        $sql$
        WITH stats AS (
            SELECT 
                percentile_cont(0.25) WITHIN GROUP (ORDER BY %I) AS q1,
                percentile_cont(0.75) WITHIN GROUP (ORDER BY %I) AS q3
            FROM %I
        ),
        iqr_bounds AS (
            SELECT 
                q1 - 1.5 * (q3 - q1) AS lower_bound,
                q3 + 1.5 * (q3 - q1) AS upper_bound
            FROM stats
        )
        SELECT 
            t.id AS primary_key,  -- Use 'id' as row identifier.
            %L AS column_name,
            t.%I AS outlier_value
        FROM %I t
        CROSS JOIN iqr_bounds b
        WHERE t.%I < b.lower_bound OR t.%I > b.upper_bound;
        $sql$, 
        target_column, target_column, target_table,
        target_column, target_column, target_table, 
        target_column, target_column
    );
END;
$$;

-- Apply the find_integer_outliers function to the 'age' column.
SELECT * FROM find_integer_outliers('marketing_data', 'age');

-- Select the top 10 highest ages to see whether the outliers detected are significant.
SELECT id, age
FROM marketing_data
ORDER BY age DESC
LIMIT 10; 

-- Delete the outliers from the 'marketing_data' table based on the 'age' column.
WITH outliers AS (
    SELECT outlier_value
    FROM find_integer_outliers('marketing_data', 'age')
)
DELETE FROM marketing_data
WHERE age IN (SELECT outlier_value FROM outliers);

-- Apply the find_integer_outliers function to the 'income_$' column.
SELECT * FROM find_integer_outliers('marketing_data', 'income_$');

-- Select the top 15 highest incomes to see whether the outliers detected are significant.
SELECT id, "income_$"
FROM marketing_data
ORDER BY "income_$" DESC
LIMIT 15;
-- Only delete row with income value of 666,666 (ID: 9432). 
-- The other detected outliers are a group of high earners with similar salaries (153,000-163,000).

-- Delete row with 9432 in the 'id' column.
DELETE FROM marketing_data
WHERE id = 9432;

/********************************************************************************
Data Preparation: ad_data.csv
********************************************************************************/

-- Create an 'ad_data' table to store advertisment information.
CREATE TABLE ad_data (
    id INT PRIMARY KEY,
    bulkmail_ad INT,
    twitter_ad INT,
    instagram_ad INT,
    facebook_ad INT,
    brochure_ad INT);

-- View the 'ad_data' table.
SELECT * FROM ad_data;

-- Check for duplicates.
SELECT ID, COUNT(*) FROM ad_data
GROUP BY ID
HAVING COUNT(*) > 1;

-- Apply the nulls_count function to the 'ad_data' table.
SELECT * FROM nulls_count('ad_data');

-- Find IDs in ad_data that are missing in the 'marketing_data' table.
SELECT id, 'missing in marketing_data' AS status
FROM ad_data 
WHERE id NOT IN (SELECT id FROM marketing_data)
UNION ALL
-- Find IDs in marketing_data that are missing in the 'ad_data' table.
SELECT id, 'missing in ad_data' AS status
FROM marketing_data 
WHERE id NOT IN (SELECT id FROM ad_data);

-- Delete IDs from ad_data that are not in the 'marketing_data' table.
DELETE FROM ad_data
WHERE id NOT IN (SELECT id FROM marketing_data);

/********************************************************************************
Analysis
********************************************************************************/

-- Total spend per country.
SELECT country, COUNT(id) AS customer_count,
       SUM(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm) AS total_spend
FROM marketing_data
GROUP BY country
ORDER BY total_spend DESC;

-- Total spend per education.
SELECT education, COUNT(id) AS customer_count,
       SUM(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm) AS total_spend
FROM marketing_data
GROUP BY education
ORDER BY total_spend DESC;

-- Total spend per marital status.
SELECT marital_status, COUNT(id) AS customer_count,
       SUM(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm) AS total_spend
FROM marketing_data
GROUP BY marital_status
ORDER BY total_spend DESC;

-- Average spend per country.
SELECT country, COUNT(id) AS customer_count,
       ROUND(AVG(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm), 2) AS average_spend
FROM marketing_data
GROUP BY country
ORDER BY average_spend DESC;

-- Average spend per education.
SELECT education, COUNT(id) AS customer_count,
       ROUND(AVG(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm), 2) AS average_spend
FROM marketing_data
GROUP BY education
ORDER BY average_spend DESC;

-- Average spend per marital status.
SELECT marital_status, COUNT(id) AS customer_count,
       ROUND(AVG(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm), 2) AS average_spend
FROM marketing_data
GROUP BY marital_status
ORDER BY average_spend DESC;

-- Average spend per product per country.
SELECT country, COUNT(id) AS customer_count,
    ROUND(AVG(amtalco), 2) AS avg_amtalco,  
    ROUND(AVG(amtvege), 2) AS avg_amtvege,   
    ROUND(AVG(amtmeat), 2) AS avg_amtmeat,   
    ROUND(AVG(amtfish), 2) AS avg_amtfish,  
    ROUND(AVG(amtchoc), 2) AS avg_amtchoc,   
    ROUND(AVG(amtcomm), 2) AS avg_amtcomm    
FROM marketing_data 
GROUP BY country   
ORDER BY country;

-- Average spend per product per education.
SELECT education, COUNT(id) AS customer_count,
    ROUND(AVG(amtalco), 2) AS avg_amtalco,  
    ROUND(AVG(amtvege), 2) AS avg_amtvege,   
    ROUND(AVG(amtmeat), 2) AS avg_amtmeat,   
    ROUND(AVG(amtfish), 2) AS avg_amtfish,  
    ROUND(AVG(amtchoc), 2) AS avg_amtchoc,   
    ROUND(AVG(amtcomm), 2) AS avg_amtcomm    
FROM marketing_data                          
GROUP BY education                               
ORDER BY education;

-- Average spend per product per marital status.
SELECT marital_status, COUNT(id) AS customer_count,
    ROUND(AVG(amtalco), 2) AS avg_amtalco,  
    ROUND(AVG(amtvege), 2) AS avg_amtvege,   
    ROUND(AVG(amtmeat), 2) AS avg_amtmeat,   
    ROUND(AVG(amtfish), 2) AS avg_amtfish,  
    ROUND(AVG(amtchoc), 2) AS avg_amtchoc,   
    ROUND(AVG(amtcomm), 2) AS avg_amtcomm    
FROM marketing_data                          
GROUP BY marital_status                               
ORDER BY marital_status;

-- Average income per country.
SELECT country, COUNT(id) AS customer_count,
       ROUND(AVG(income_$), 2) AS average_income
FROM marketing_data
GROUP BY country
ORDER BY average_income DESC;

-- Average income per education.
SELECT education, COUNT(id) AS customer_count,
       ROUND(AVG(income_$), 2) AS average_income
FROM marketing_data
GROUP BY education
ORDER BY average_income DESC;

-- Average income per marital status.
SELECT marital_status, COUNT(id) AS customer_count,
       ROUND(AVG(income_$), 2) AS average_income
FROM marketing_data
GROUP BY marital_status
ORDER BY average_income DESC;

-- Create or replace a function to retrieve the top three incomes by a specified column, 
-- ranked overall across all categories.
CREATE OR REPLACE FUNCTION top_three_incomes_by(target_column TEXT)
RETURNS TABLE (
    category TEXT,
    income NUMERIC,
    overall_rank BIGINT
) AS $$
BEGIN
    RETURN QUERY EXECUTE format(
        'WITH ranked_incomes AS (
            SELECT %I::TEXT AS category, 
                   income_$::NUMERIC AS income,
                   ROW_NUMBER() OVER (PARTITION BY %I ORDER BY income_$ DESC) AS category_rank,
                   RANK() OVER (ORDER BY income_$ DESC) AS overall_rank
            FROM marketing_data
        )
        SELECT category, 
               income, 
               overall_rank
        FROM ranked_incomes
        WHERE category_rank <= 3
        ORDER BY overall_rank;',
         target_column, target_column
    );
END;
$$ LANGUAGE plpgsql;

-- Apply the top_three_incomes_by function to country.
SELECT * FROM top_three_incomes_by('country');

-- Apply the top_three_incomes_by function to education.
SELECT * FROM top_three_incomes_by('education');

-- Apply the top_three_incomes_by function to marital_status.
SELECT * FROM top_three_incomes_by('marital_status');

-- Average number of deals, number of web visits, number of web purchases, 
-- and number of walkin purchases per country.
SELECT country, COUNT(id) AS customer_count,
       ROUND(AVG(numdeals), 2) AS avg_numdeals,
       ROUND(AVG(numwebvisits), 2) AS avg_numwebvisits,
       ROUND(AVG(numwebbuy), 2) AS avg_numwebbuy,
       ROUND(AVG(numwalkinbuy), 2) AS avg_numwalkinbuy
FROM marketing_data
GROUP BY country
ORDER BY country;

-- Average number of deals, number of web visits, number of web purchases, 
-- and number of walk-in purchases per education.
SELECT education, COUNT(id) AS customer_count,
       ROUND(AVG(numdeals), 2) AS avg_numdeals,
       ROUND(AVG(numwebvisits), 2) AS avg_numwebvisits,
       ROUND(AVG(numwebbuy), 2) AS avg_numwebbuy,
       ROUND(AVG(numwalkinbuy), 2) AS avg_numwalkinbuy
FROM marketing_data
GROUP BY education
ORDER BY education;

-- Average number of deals, number of web visits, number of web purchases, 
-- and number of walk-in purchases per marital status.
SELECT marital_status, COUNT(id) AS customer_count,
       ROUND(AVG(numdeals), 2) AS avg_numdeals,
       ROUND(AVG(numwebvisits), 2) AS avg_numwebvisits,
       ROUND(AVG(numwebbuy), 2) AS avg_numwebbuy,
       ROUND(AVG(numwalkinbuy), 2) AS avg_numwalkinbuy
FROM marketing_data
GROUP BY marital_status
ORDER BY marital_status;

-- Average responses, complaints, and successful converstions per country.
SELECT country, COUNT(id) AS customer_count,
	ROUND(AVG(response), 2) AS avg_response,
	ROUND(AVG(complain), 3) AS avg_complain,
	ROUND(AVG(count_success), 2) AS avg_count_success
FROM marketing_data
GROUP BY country
ORDER BY country;

-- Average responses, complaints, and successful conversions per education.
SELECT education, COUNT(id) AS customer_count,
       ROUND(AVG(response), 2) AS avg_response,
       ROUND(AVG(complain), 3) AS avg_complain,
       ROUND(AVG(count_success), 2) AS avg_count_success
FROM marketing_data
GROUP BY education
ORDER BY education;

-- Average responses, complaints, and successful conversions per marital status.
SELECT marital_status, COUNT(id) AS customer_count,
       ROUND(AVG(response), 2) AS avg_response,
       ROUND(AVG(complain), 3) AS avg_complain,
       ROUND(AVG(count_success), 2) AS avg_count_success
FROM marketing_data
GROUP BY marital_status
ORDER BY marital_status;

-- Total advertisement effectiveness percentage and the effectiveness percentage for each individual advertisement type.
SELECT 
    ROUND((SUM(bulkmail_ad + twitter_ad + instagram_ad + facebook_ad + brochure_ad) * 100.0) / 
    COUNT(id), 2) AS total_ad_effectiveness_percentage,
    ROUND((SUM(brochure_ad) * 100.0) / COUNT(id), 2) AS brochure_ad_effectiveness_percentage,
    ROUND((SUM(bulkmail_ad) * 100.0) / COUNT(id), 2) AS bulkmail_ad_effectiveness_percentage,
    ROUND((SUM(facebook_ad) * 100.0) / COUNT(id), 2) AS facebook_ad_effectiveness_percentage,
    ROUND((SUM(instagram_ad) * 100.0) / COUNT(id), 2) AS instagram_ad_effectiveness_percentage,
    ROUND((SUM(twitter_ad) * 100.0) / COUNT(id), 2) AS twitter_ad_effectiveness_percentage
FROM ad_data;

-- Create or replace function to retrieve advertisement effectiveness percentages by a specified column.
CREATE OR REPLACE FUNCTION ad_effectiveness_by(target_column TEXT)
RETURNS TABLE (
    category TEXT,
    customer_count BIGINT,
    total_effectiveness_percentage NUMERIC,
    brochure_effectiveness_percentage NUMERIC,
    bulkmail_effectiveness_percentage NUMERIC,
    facebook_effectiveness_percentage NUMERIC,
    instagram_effectiveness_percentage NUMERIC,
    twitter_effectiveness_percentage NUMERIC
) AS $$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT %I::TEXT AS category, COUNT(md.id) AS customer_count,
                ROUND((SUM(ad.brochure_ad) + SUM(ad.bulkmail_ad) + SUM(ad.facebook_ad) + 
                SUM(ad.instagram_ad) + SUM(ad.twitter_ad)) * 100.0 / COUNT(md.id), 2) AS total_effectiveness_percentage, 
                ROUND(SUM(ad.brochure_ad) * 100.0 / COUNT(md.id), 2) AS brochure_effectiveness_percentage,
                ROUND(SUM(ad.bulkmail_ad) * 100.0 / COUNT(md.id), 2) AS bulkmail_effectiveness_percentage,
                ROUND(SUM(ad.facebook_ad) * 100.0 / COUNT(md.id), 2) AS facebook_effectiveness_percentage,
                ROUND(SUM(ad.instagram_ad) * 100.0 / COUNT(md.id), 2) AS instagram_effectiveness_percentage,
                ROUND(SUM(ad.twitter_ad) * 100.0 / COUNT(md.id), 2) AS twitter_effectiveness_percentage
         FROM marketing_data md
         JOIN ad_data ad ON md.id = ad.id
         GROUP BY %I
         ORDER BY total_effectiveness_percentage DESC;',
         target_column, target_column
    );
END;
$$ LANGUAGE plpgsql;

-- Apply the ad_effectiveness_by function to country.
SELECT * FROM ad_effectiveness_by('country');

-- Apply the ad_effectiveness_by function to education.
SELECT * FROM ad_effectiveness_by('education');

-- Apply the ad_effectiveness_by function to marital_status.
SELECT * FROM ad_effectiveness_by('marital_status');