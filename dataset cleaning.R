library(dplyr)
library(DBI)
library(duckdb)


#creates a duckdbobject in the computer memory, NOT RAM
setwd("/home/mario/Scrivania/spotify project/spotify project")
Spotidy_database <- dbConnect(duckdb(), dbdir = "spotify_database.duckdb", read_only = FALSE)

#import all of the files of songs into the database
dbExecute(Spotidy_database,
          "CREATE TABLE X2018_2019 AS SELECT * FROM read_csv('/home/mario/Desktop/spotify project/spotify project/spotify data csv/data into csv')"
          ) 

#i wrote the wrong name, so i changed it
dbExecute(Spotidy_database,
          "ALTER TABLE X2018_2019 RENAME TO SONGS2018_2025")

#i have 21 variables that are: ts(timestamp) , platform, ms_played, ip_address, trackname,
#album name
#spotify_track url
#episode_name
#episode show name
#spotify episode url
#audiobook title
#audibook url
#audiobook chapter
#audiobook chapter title
#reason start
#reason end
#shuffle
#skipped
#offline
#offline timestamp
#incognito mode
#conn_country

#of these variables i just need, track name, album name, artist of the track name
#ms played and timestamp.

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN episode_name ") #deletes episode name column

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN episode_show_name ") 

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN spotify_episode_uri ")  

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN audiobook_title ") 

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN audiobook_uri")

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN audiobook_chapter_uri ")

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN audiobook_chapter_title ")

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN offline ")

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN offline_timestamp ")

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN incognito_mode ")

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN  platform")

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN  conn_country")

dbExecute(Spotidy_database, "ALTER TABLE SONGS2018_2025
          DROP COLUMN  ip_addr")

#now we have just 10 variables that we need to giev to the APi to get the 
#genre of the songs


skrt<- tbl(Spotidy_database, "SONGS2018_2025") |>
  collect()

tbl(Spotidy_database, "SONGS2018_2025") |>
  is.na()
  collect()
#dbGetQuery(Spotidy_database, "SELECT * FROM SONGS2018_2025 WHERE rowid = 1")

