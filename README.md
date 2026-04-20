# LSTM Model for Music Genre Classification

## Overview
This repository contains an LSTM (Long Short-Term Memory) neural network built to predict the genre of songs. The project handles everything from data imputation to model training and evaluation, and was developed entirely in **R** using **RStudio**.

## Methodology

### 1. Data Preprocessing & Missing Label Imputation
When you download the dataset from spotify, youb will have different files with songs from variopus year in cronological order.
The files will have to be organized deleting various rows that are not needed and you will also need to get the genre of the artist using the spotify API.
i used duckdb to organize all of the files but you don't need to do that. 

One of the primary challenges with the initial dataset was a subset of unclassified songs missing their genre labels. The daaset has been gathered from spotify directly and then modified using a duckdb database on my compuetr since my ram couldn't handle all of them togheter. Then the unclassified songs issue was solved with a small LLM (Large Language Model) was utilized to analyze the available song metadata/lyrics and accurately classify the previously unclassified tracks. This enriched the corpus and provided a robust, complete dataset for the neural network.


### 2. Model Building
The predictive model is based on an LSTM architecture, well-suited for sequential data. It was implemented in R, taking advantage of deep learning libraries available within the R ecosystem. 

### 3. Hyperparameter Tuning
Various model configurations and settings were tested to find the optimal architecture. Experiments included tuning:
* Number of LSTM layers and units
* Dropout rates for regularization
* Batch sizes and learning rates

## Results
After extensive tuning and experimentation, the final LSTM model achieved a **Top-5 Accuracy of 80% (0.80)**. This means that for any given song, the model's top 5 predicted genres contain the correct genre 80% of the time.

![alt text](https://github.com/TheFreshMarx/LTSM-model-for-predicting-spotify-genres-of-your-spotify-history/blob/main/best%20model%20training.png?raw=true)


## Technologies Used
* **Language:** R
* **Environment:** RStudio
* **Data Processing:** Small LLM (for genre imputation)
* **Modeling:** LSTM Neural Network 

## Repository Structure
* `dataset cleaning.R` - R scripts for data cleaning and preprocessing.
* `Neural network.R` - The R scripts containing the LSTM architecture, training loops, and hyperparameter testing logs.
* `LTSMmodel_genre.weights.h5` - Contains the weight for which i got 80% accuracy.

## How to Run
1. Clone this repository to your local machine.
2. Read the methodology since you will need different things to run the model, like the genre of the artist that unfortunately spotify will not give you. 
3. Open the `.Rproj` file in RStudio.
4. Ensure you have the necessary R packages installed (e.g., `keras`, `tensorflow`, `dplyr`, etc.).
5. Run the data preprocessing scripts first to see the LLM classification process, followed by the main model training script.
