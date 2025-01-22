-- Imported marketing_data.csv into Excel to check the format of the date column.
-- Used Text to Column twice for Dt_Customer to handle the difference in date formats (DMY and MDY).
-- Changed the date format to YYYY-MM-DD to import file into pgAdmin4.

-- Create the marketing_data table to store customer information.
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
    count_success INT
);

-- View the updated marketing_data table.
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

-- View the updated marketing_data table.
SELECT * FROM marketing_data;

-- Check for duplicates in the 'id' column.
SELECT id, COUNT(*)
FROM marketing_data
GROUP BY id
HAVING COUNT(*) > 1;

-- Check for NULL values in all columns.
SELECT
    COUNT(*) FILTER (WHERE year_birth IS NULL) AS year_birth_nulls,
    COUNT(*) FILTER (WHERE education IS NULL) AS education_nulls,
    COUNT(*) FILTER (WHERE marital_status IS NULL) AS marital_status_nulls,
    COUNT(*) FILTER (WHERE income_$ IS NULL) AS income_nulls,
    COUNT(*) FILTER (WHERE kidhome IS NULL) AS kidhome_nulls,
    COUNT(*) FILTER (WHERE teenhome IS NULL) AS teenhome_nulls,
    COUNT(*) FILTER (WHERE customer_reg IS NULL) AS customer_reg_nulls,
    COUNT(*) FILTER (WHERE recency IS NULL) AS recency_nulls,
    COUNT(*) FILTER (WHERE amtalco IS NULL) AS amtalco_nulls,
    COUNT(*) FILTER (WHERE amtvege IS NULL) AS amtvege_nulls,
    COUNT(*) FILTER (WHERE amtmeat IS NULL) AS amtmeat_nulls,
    COUNT(*) FILTER (WHERE amtfish IS NULL) AS amtfish_nulls,
    COUNT(*) FILTER (WHERE amtchoc IS NULL) AS amtchoc_nulls,
    COUNT(*) FILTER (WHERE amtcomm IS NULL) AS amtcomm_nulls,
    COUNT(*) FILTER (WHERE numdeals IS NULL) AS numdeals_nulls,
    COUNT(*) FILTER (WHERE numwebbuy IS NULL) AS numwebbuy_nulls,
    COUNT(*) FILTER (WHERE numwalkinbuy IS NULL) AS numwalkinbuy_nulls,
    COUNT(*) FILTER (WHERE numwebvisits IS NULL) AS numwebvisits_nulls,
    COUNT(*) FILTER (WHERE response IS NULL) AS response_nulls,
    COUNT(*) FILTER (WHERE complain IS NULL) AS complain_nulls,
    COUNT(*) FILTER (WHERE country IS NULL) AS country_nulls,
    COUNT(*) FILTER (WHERE count_success IS NULL) AS count_success_nulls
FROM marketing_data;

-- Show all distinct values in the 'education' column.
SELECT DISTINCT education
FROM marketing_data
ORDER BY education;

-- Show all distinct values in the 'marital_status' column.
SELECT DISTINCT marital_status
FROM marketing_data
ORDER BY marital_status;

-- Remove rows where marital_status is 'YOLO' or 'Absurd'.
DELETE FROM marketing_data
WHERE marital_status IN ('YOLO', 'Absurd');

-- Change marital_status value 'Alone' to 'Single'.
UPDATE marketing_data
SET marital_status = 'Single'
WHERE marital_status = 'Alone';

-- Show all distinct values in the 'marital_status' column to check changes have been made.
SELECT DISTINCT marital_status
FROM marketing_data
ORDER BY marital_status;

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

-- Add an 'age' column to the marketing_data table.
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
    in_table_name TEXT, 
    in_column_name TEXT
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
            t.id AS primary_key,
            %L AS column_name,
            t.%I AS outlier_value
        FROM %I t
        CROSS JOIN iqr_bounds b
        WHERE t.%I < b.lower_bound OR t.%I > b.upper_bound;
        $sql$, 
        in_column_name, in_column_name, in_table_name,
        in_column_name, in_column_name, in_table_name, 
        in_column_name, in_column_name
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

-- Delete the outliers from the marketing_data table based on the 'age' column.
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

/********************************************************************************/

-- Create a ad_data table to store advertisment information.
CREATE TABLE ad_data (
    id INT PRIMARY KEY,
    bulkmail_ad INT,
    twitter_ad INT,
    instagram_ad INT,
    facebook_ad INT,
    brochure_ad INT
);

-- View the ad_data table.
SELECT * FROM ad_data;

-- Check for duplicates.
SELECT ID, COUNT(*) FROM ad_data
GROUP BY ID
HAVING COUNT(*) > 1;

-- Check for NULL values.
SELECT *
FROM ad_data
WHERE bulkmail_ad IS NULL
   OR twitter_ad IS NULL
   OR instagram_ad IS NULL
   OR facebook_ad IS NULL
   OR brochure_ad IS NULL;

-- Find IDs in ad_data that are missing in marketing_data.
SELECT id, 'missing in marketing_data' AS status
FROM ad_data 
WHERE id NOT IN (SELECT id FROM marketing_data)
UNION ALL
-- Find IDs in marketing_data that are missing in ad_data.
SELECT id, 'missing in ad_data' AS status
FROM marketing_data 
WHERE id NOT IN (SELECT id FROM ad_data);

-- Delete IDs from ad_data that are not in marketing_data.
DELETE FROM ad_data
WHERE id NOT IN (SELECT id FROM marketing_data);

/********************************************************************************/

-- Total spend per country.
SELECT country, COUNT(id) AS customer_count,
       SUM(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm) AS total_spend
FROM marketing_data
GROUP BY country
ORDER BY total_spend DESC;

-- Average spend per country.
SELECT country, COUNT(id) AS customer_count,
       ROUND(AVG(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm), 2) AS average_spend
FROM marketing_data
GROUP BY country
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

-- UPDATE NEEDED: Average responses, complaints, and successful converstions per country.
SELECT country, COUNT(id) AS customer_count,
	ROUND(AVG(response), 2) AS avg_response,
	ROUND(AVG(complain), 3) AS avg_complain,
	ROUND(AVG(count_success), 2) AS avg_count_success
FROM marketing_data
GROUP BY country
ORDER BY country;

-- Average income per country.
SELECT country, COUNT(id) AS customer_count,
       ROUND(AVG(income_$), 2) AS average_income
FROM marketing_data
GROUP BY country
ORDER BY average_income DESC;

-- Top three incomes per country, ranked overall across all countries.
WITH ranked_incomes AS (
    SELECT country, 
           income_$,
           ROW_NUMBER() OVER (PARTITION BY country ORDER BY income_$ DESC) AS country_rank,
           RANK() OVER (ORDER BY income_$ DESC) AS overall_rank
    FROM marketing_data
)
SELECT country, 
       income_$, 
       overall_rank
FROM ranked_incomes
WHERE country_rank <= 3
ORDER BY overall_rank;

-- Total spend per marital_status.
SELECT marital_status, COUNT(id) AS customer_count,
       SUM(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm) AS total_spend
FROM marketing_data
GROUP BY marital_status
ORDER BY total_spend DESC;

-- Average spend per marital_status.
SELECT marital_status, COUNT(id) AS customer_count,
       ROUND(AVG(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm), 2) AS average_spend
FROM marketing_data
GROUP BY marital_status
ORDER BY average_spend DESC;

-- Average spend per product per marital_status.
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

-- Average number of deals, number of web visits, number of web purchases, 
-- and number of walk-in purchases per marital_status.
SELECT marital_status, COUNT(id) AS customer_count,
       ROUND(AVG(numdeals), 2) AS avg_numdeals,
       ROUND(AVG(numwebvisits), 2) AS avg_numwebvisits,
       ROUND(AVG(numwebbuy), 2) AS avg_numwebbuy,
       ROUND(AVG(numwalkinbuy), 2) AS avg_numwalkinbuy
FROM marketing_data
GROUP BY marital_status
ORDER BY marital_status;

-- Average responses, complaints, and successful conversions per marital_status.
SELECT marital_status, COUNT(id) AS customer_count,
       ROUND(AVG(response), 2) AS avg_response,
       ROUND(AVG(complain), 3) AS avg_complain,
       ROUND(AVG(count_success), 2) AS avg_count_success
FROM marketing_data
GROUP BY marital_status
ORDER BY marital_status;

-- Average income per marital_status.
SELECT marital_status, COUNT(id) AS customer_count,
       ROUND(AVG(income_$), 2) AS average_income
FROM marketing_data
GROUP BY marital_status
ORDER BY average_income DESC;

-- Top three incomes per marital_status, ranked overall across the whole dataset.
WITH ranked_incomes AS (
    SELECT marital_status, 
           income_$,
           ROW_NUMBER() OVER (PARTITION BY marital_status ORDER BY income_$ DESC) AS marital_status_rank,
           RANK() OVER (ORDER BY income_$ DESC) AS overall_rank
    FROM marketing_data
)
SELECT marital_status, 
       income_$, 
       overall_rank
FROM ranked_incomes
WHERE marital_status_rank <= 3
ORDER BY overall_rank;

-- Total spend per education.
SELECT education, COUNT(id) AS customer_count,
       SUM(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm) AS total_spend
FROM marketing_data
GROUP BY education
ORDER BY total_spend DESC;

-- Average spend per education.
SELECT education, COUNT(id) AS customer_count,
       ROUND(AVG(amtalco + amtvege + amtmeat + amtfish + amtchoc + amtcomm), 2) AS average_spend
FROM marketing_data
GROUP BY education
ORDER BY average_spend DESC;

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

-- Average responses, complaints, and successful conversions per education.
SELECT education, COUNT(id) AS customer_count,
       ROUND(AVG(response), 2) AS avg_response,
       ROUND(AVG(complain), 3) AS avg_complain,
       ROUND(AVG(count_success), 2) AS avg_count_success
FROM marketing_data
GROUP BY education
ORDER BY education;

-- Average income per education level.
SELECT education, COUNT(id) AS customer_count,
       ROUND(AVG(income_$), 2) AS average_income
FROM marketing_data
GROUP BY education
ORDER BY average_income DESC;

-- Top three incomes per education, ranked overall across the whole dataset.
WITH ranked_incomes AS (
    SELECT education, 
           income_$,
           ROW_NUMBER() OVER (PARTITION BY education ORDER BY income_$ DESC) AS education_rank,
           RANK() OVER (ORDER BY income_$ DESC) AS overall_rank
    FROM marketing_data
)
SELECT education, 
       income_$, 
       overall_rank
FROM ranked_incomes
WHERE education_rank <= 3
ORDER BY overall_rank;

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

-- Advertisement effectiveness percentage per country with total effectiveness percentage.
SELECT md.country, COUNT(md.id) AS customer_count,
    ROUND(
        (SUM(ad.brochure_ad) + SUM(ad.bulkmail_ad) + SUM(ad.facebook_ad) + 
        SUM(ad.instagram_ad) + SUM(ad.twitter_ad)) * 100.0 / COUNT(md.id), 2
    ) AS total_effectiveness_percentage, 
    ROUND(SUM(ad.brochure_ad) * 100.0 / COUNT(md.id), 2) AS brochure_effectiveness_percentage,
    ROUND(SUM(ad.bulkmail_ad) * 100.0 / COUNT(md.id), 2) AS bulkmail_effectiveness_percentage,
    ROUND(SUM(ad.facebook_ad) * 100.0 / COUNT(md.id), 2) AS facebook_effectiveness_percentage,
    ROUND(SUM(ad.instagram_ad) * 100.0 / COUNT(md.id), 2) AS instagram_effectiveness_percentage,
    ROUND(SUM(ad.twitter_ad) * 100.0 / COUNT(md.id), 2) AS twitter_effectiveness_percentage
FROM marketing_data md
JOIN ad_data ad 
    ON md.id = ad.id
GROUP BY md.country
ORDER BY total_effectiveness_percentage DESC;

-- Advertisement effectiveness percentage per marital_status with total effectiveness percentage.
SELECT md.marital_status, COUNT(md.id) AS customer_count,
    ROUND(
        (SUM(ad.brochure_ad) + SUM(ad.bulkmail_ad) + SUM(ad.facebook_ad) + 
        SUM(ad.instagram_ad) + SUM(ad.twitter_ad)) * 100.0 / COUNT(md.id), 2
    ) AS total_effectiveness_percentage, 
    ROUND(SUM(ad.brochure_ad) * 100.0 / COUNT(md.id), 2) AS brochure_effectiveness_percentage,
    ROUND(SUM(ad.bulkmail_ad) * 100.0 / COUNT(md.id), 2) AS bulkmail_effectiveness_percentage,
    ROUND(SUM(ad.facebook_ad) * 100.0 / COUNT(md.id), 2) AS facebook_effectiveness_percentage,
    ROUND(SUM(ad.instagram_ad) * 100.0 / COUNT(md.id), 2) AS instagram_effectiveness_percentage,
    ROUND(SUM(ad.twitter_ad) * 100.0 / COUNT(md.id), 2) AS twitter_effectiveness_percentage
FROM marketing_data md
JOIN ad_data ad 
    ON md.id = ad.id
GROUP BY md.marital_status
ORDER BY total_effectiveness_percentage DESC;

-- Advertisement effectiveness percentage per education with total effectiveness percentage.
SELECT md.education, COUNT(md.id) AS customer_count,
    ROUND(
        (SUM(ad.brochure_ad) + SUM(ad.bulkmail_ad) + SUM(ad.facebook_ad) + 
        SUM(ad.instagram_ad) + SUM(ad.twitter_ad)) * 100.0 / COUNT(md.id), 2
    ) AS total_effectiveness_percentage, 
    ROUND(SUM(ad.brochure_ad) * 100.0 / COUNT(md.id), 2) AS brochure_effectiveness_percentage,
    ROUND(SUM(ad.bulkmail_ad) * 100.0 / COUNT(md.id), 2) AS bulkmail_effectiveness_percentage,
    ROUND(SUM(ad.facebook_ad) * 100.0 / COUNT(md.id), 2) AS facebook_effectiveness_percentage,
    ROUND(SUM(ad.instagram_ad) * 100.0 / COUNT(md.id), 2) AS instagram_effectiveness_percentage,
    ROUND(SUM(ad.twitter_ad) * 100.0 / COUNT(md.id), 2) AS twitter_effectiveness_percentage
FROM marketing_data md
JOIN ad_data ad 
    ON md.id = ad.id
GROUP BY md.education
ORDER BY total_effectiveness_percentage DESC;