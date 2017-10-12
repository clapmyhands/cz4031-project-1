-- QUERY 1

SELECT type, COUNT(*)
FROM (
      (
       SELECT 'book' as type, extract(year from pub_date) as year
       FROM book
       )
      UNION ALL
      (
       SELECT 'incollection' as type, extract(year from pub_date) as year
       FROM incollection
       )
      UNION ALL
      (
       SELECT 'masters_thesis' as type, extract(year from pub_date) as year
       FROM masters_thesis
       )
      UNION ALL
      (
       SELECT 'phd_thesis' as type, extract(year from pub_date) as year
       FROM phd_thesis
       )
      UNION ALL
      (
       SELECT 'proceedings' as type, extract(year from pub_date) as year
       FROM proceedings
       )
      UNION ALL
      (
       SELECT 'inproceedings' as type, extract(year from pub_date) as year
       FROM inproceedings
       )
      UNION ALL
      (
       SELECT 'article' as type, extract(year from pub_date) as year
       FROM article
       )
      ) AS publ_list
WHERE year BETWEEN 2000 AND 2017
GROUP BY type
ORDER BY type;

-- QUERY 2
SELECT *
FROM (
      SELECT booktitle, extract(year from pub_date) as year, COUNT(*) AS conferences_count
      FROM (
            SELECT *
            FROM proceedings_inproceedings
            WHERE extract(month from pub_date) = 'July'
            ) AS julyConferences
      GROUP BY booktitle, year
      ) AS result_set
WHERE conferences_count > 200;

-- QUERY 3
DROP VIEW IF EXISTS publication_author CASCADE;

CREATE VIEW publication_author AS 
(
   SELECT pb.pub_id, pb.title, pb.pub_date, a.author_name
   FROM publication AS pb, authored AS aed, author AS a
   WHERE pb.pub_id = aed.pub_id AND aed.author_id = a.author_id
   ORDER BY pb.pub_id
);

-- (3a)
SELECT name, pub_id, title
FROM publication_author
WHERE author_name = 'Kurni' AND extract(year from pub_date) = 2015;

-- (3b)
SELECT name, pa.pub_id, pa.title
FROM publication_author pa, proceedings_inproceedings i
WHERE pa.pub_id = i.pub_id AND author_name = 'Stefan' AND pa.pub_date = 2012 AND i.booktitle = 'KDD';

-- (3c)
SELECT *
FROM (
      SELECT name, booktitle, pa.pub_date, COUNT(*) AS paper_count
      FROM proceedings_inproceedings AS i
      JOIN publication_author AS pa
      ON i.pub_id = pa.pub_id
      GROUP BY name, booktitle, pa.pub_date
   ) AS result_set
WHERE author_name = 'Stefan' AND extract(year from pub_date) = 1980 AND booktitle = 'KDD' AND paper_count > 2;


-- QUERY 4
-- I assume that by 'SIGMOD papers' the question meant any publications under
-- conference/journal SIGMOD

DROP VIEW IF EXISTS confjournalpapers CASCADE;
DROP VIEW IF EXISTS papers_with_authors CASCADE;

CREATE VIEW confjournalpapers AS (
   SELECT *
   FROM (
      SELECT pub_id, title, booktitle AS confjournal
      FROM inproceedings
   ) AS result_set

   UNION (
      SELECT pub_id, title, journal AS confjournal
      FROM article
   )
);

CREATE VIEW papers_with_authors AS (
   SELECT cjp.*, pa.author_name
   FROM confjournalpapers cjp, publication_author pa
   WHERE cjp.pub_id = pa.pub_id
);

-- (4a)
SELECT DISTINCT pwa1.author_name 
FROM papers_with_authors pwa1
WHERE pwa1.author_name IN (
   SELECT DISTINCT name
   FROM papers_with_authors
   WHERE confjournal = 'PVLDB'
   GROUP BY name, confjournal
   HAVING COUNT(DISTINCT pub_id) > 10
) INTERSECT (
   SELECT DISTINCT name
   FROM papers_with_authors
   WHERE confjournal = 'SIGMOD'
   GROUP BY name, confjournal
   HAVING COUNT(DISTINCT pub_id) > 10
);

-- (4b)
SELECT DISTINCT pwa1.author_name 
FROM papers_with_authors pwa1
WHERE pwa1.author_name IN (
   SELECT DISTINCT name
   FROM papers_with_authors
   WHERE confjournal = 'PVLDB'
   GROUP BY name, confjournal
   HAVING COUNT(DISTINCT pub_id) > 15
) AND pwa1.author_name NOT IN (
   SELECT DISTINCT name
   FROM papers_with_authors
   WHERE confjournal = 'KDD'
   GROUP BY name, confjournal
   HAVING COUNT(DISTINCT pub_id) = 0
);

-- QUERY 5
SELECT * INTO yearly_count
FROM (
      SELECT extract(year from pub_date) as year, COUNT(*) as paper_count
      FROM inproceedings
      GROUP BY year
      ) AS result_set;


SELECT *
FROM (
      (
       SELECT '1970-1979' AS year_range, paper_count
       FROM yearly_count
       WHERE extract(year from pub_date) BETWEEN 1970 AND 1979
       )

      UNION
      (
       SELECT '1980-1989' AS year_range, paper_count
       FROM yearly_count
       WHERE extract(year from pub_date) BETWEEN 1980 AND 1989
       )

      UNION
      (
       SELECT '1990-1999' AS year_range, paper_count
       FROM yearly_count
       WHERE extract(year from pub_date) BETWEEN 1990 AND 1999
       )

      UNION
      (
       SELECT '2000-2009' AS year_range, paper_count
       FROM yearly_count
       WHERE extract(year from pub_date) BETWEEN 2000 AND 2009
       )

      UNION
      (
       SELECT '2010-2019' AS year_range, paper_count
       FROM yearly_count
       WHERE extract(year from pub_date) BETWEEN 2010 AND 2019
       )
      ) as result_set
ORDER BY year_range;

DROP TABLE yearly_count;

-- QUERY 6
DROP VIEW IF EXISTS data_conferences CASCADE;
DROP VIEW IF EXISTS collaborators CASCADE;
DROP VIEW IF EXISTS collaborators_count CASCADE;

CREATE VIEW data_conferences AS 
(
   SELECT *
   FROM papers_with_authors
   WHERE title SIMILAR TO '%[dD]ata%'
);

CREATE VIEW collaborators AS
(
   SELECT dc1.author_name, dc2.author_name as collaborator
   FROM data_conferences dc1
   JOIN data_conferences dc2 ON dc1.pub_id = dc2.pub_id AND NOT dc1.author_name = dc2.author_name
);

CREATE VIEW collaborators_count AS
(
   SELECT name, COUNT(DISTINCT collaborator) as collab_count
   FROM collaborators
   GROUP BY name
   ORDER BY collab_count DESC
);

SELECT name
FROM collaborators_count
WHERE collab_count = (SELECT MAX(collab_count) FROM collaborators_count)
ORDER BY name;

-- QUERY 7
DROP VIEW IF EXISTS data_conferences_5year CASCADE;

CREATE VIEW data_conferences_5year AS (
    SELECT *
    FROM papers_with_authors
    WHERE title SIMILAR TO '%[dD]ata%' AND extract(year from pub_date) BETWEEN 2013 AND 2017
);

SELECT name, COUNT(DISTINCT pub_id) AS pub_count
FROM data_conferences_5year
GROUP BY name
ORDER BY pub_count DESC
LIMIT 10;

-- QUERY 8
DROP VIEW IF EXISTS valid_conferences CASCADE;

CREATE VIEW valid_conferences AS (
    SELECT booktitle, extract(year from pub_date) as year, COUNT(*) AS pub_count
    FROM inproceedings
    WHERE booktitle in (
        SELECT DISTINCT booktitle 
        FROM proceedings_inproceedings
        WHERE extract(month from pub_date) = 'June'
    )
    GROUP BY booktitle, year
);

SELECT DISTINCT booktitle
FROM valid_conferences
WHERE pub_count > 100

-- QUERY 9
-- (9a)
DROP VIEW IF EXISTS diligent_authors CASCADE;

CREATE VIEW diligent_authors AS (
   SELECT name, extract(year from pub_date) as year
   FROM publication_author
   WHERE extract(year from pub_date) BETWEEN 1988 AND 2017 AND author_name SIMILAR TO '% H[a-z\.]*'
   GROUP BY name, year
   HAVING COUNT(*) = 30
);

SELECT DISTINCT name
FROM diligent_authors;

-- (9b)
SELECT name, COUNT(*)
FROM publication_author
GROUP BY name
ORDER BY pub_date DESC

-- QUERY 10
-- For each year, find the author with the most publication published and the number of publications by that author.
DROP VIEW IF EXISTS yearly_author_pub_count CASCADE;

CREATE VIEW yearly_author_pub_count AS (
    SELECT extract(year from pub_date) as year, author_name, COUNT(*) AS pub_count
    FROM publication_author
    GROUP BY year, author_name
    ORDER BY year, COUNT(*) DESC
);

WITH result AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY year ORDER BY pub_count DESC) AS row
    FROM yearly_author_pub_count
)
SELECT year, author_name, pub_count
FROM result
WHERE row = 1;

-- Query to delete duplicates in author and then update the authored table
-- Copy author table but without duplicates. Use the author_id with the smallest number.
WITH result AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY author_name ORDER BY author_id) AS row
    FROM author
)
SELECT author_id, author_name 
INTO distinct_name
FROM result
WHERE row = 1;

-- Update the authored table
DO $$
DECLARE
    rec RECORD;
BEGIN
  FOR rec IN (SELECT * FROM distinct_name) LOOP
  UPDATE authored
  SET author_id = rec.author_id
  WHERE author_id IN (SELECT a.author_id FROM author a WHERE a.author_name = rec.author_name);
  END LOOP;
END $$;

-- Replace author table with the one without duplicates
DROP TABLE author;
ALTER TABLE distinct_name RENAME TO author;
