
# libraries ----------------------------------------------------------------
library(dplyr)
library(ollamar)
library(stringr)
library(DBI)
library(duckdb)

library(keras)
library(keras3)
library(tensorflow)

# dataset preparing -------------------------------------------------------

#since my dataset it's not complete, since it has a few NOT CLASSIFIED items
#i need to classify those items
#to do that i will use an LLM

Spotidy_database <- dbConnect(duckdb(), dbdir = "spotify_database.duckdb", read_only = FALSE)
spoti_data<- tbl(Spotidy_database, "SONGS2018_2025") |>
  collect()

LTSM_dataset <- spoti_data |>
  mutate(spotify_track_uri = NULL) |>
  filter(!is.na(master_metadata_track_name)) #i removed the songs that didn't have a name


# LLM requests ------------------------------------------------------------

#we need to connect to the LLM
test_connection() #it tells you if ollama is running
pull("gemma3:4b")
pull("gemma3:1b")
list_models()

resp <- generate("gemma3:1b", "Tell me the genre of BAZZI the musical artist. Respond with just one genre that most represent the artist.", output = "text")
#a test

index_vector <- which(LTSM_dataset$genre_of_artist == "NOT CLASSIFIED") #i need the indexes of the artist
artist <- unique(LTSM_dataset$master_metadata_album_artist_name[index_vector]) #i will retrieve the artist

#i'm gonna do a for loop
for (i in 1: length(artist)) {
  #i will use gemma3:1b since it's faster then the gemma3:4b model
  response <-generate("gemma3:1b", paste0(
                             "Tell me the genre of",
                             artist[i],
                             "the musical artist.
                             Respond with just one genre that most represent the artist."),
                             output = "text")
 index <- which(LTSM_dataset$master_metadata_album_artist_name == artist[i])
 #i'm gonna paste the genre for every row that the artist has
  LTSM_dataset$genre_of_artist[index] <- response
  print(i)#a check on the progress
}
#it took 2 hours

# neural network model ----------------------------------------------------

#now that i have the dataset ready, i will feed it into the neural network
LTSM_dataset <- LTSM_dataset |>
  mutate(ms_played= NULL ,
          master_metadata_track_name = NULL, 
         master_metadata_album_artist_name = NULL,
         master_metadata_album_album_name = NULL, 
         shuffle = NULL,
         reason_end = NULL, 
         reason_start = NULL, 
         skipped = NULL)

tokenizer <- text_tokenizer(filters = "") |>
  fit_text_tokenizer(LTSM_dataset$genre_of_artist) #takes a general tokenization and fit to the genres that i have

genre_to_token <- texts_to_sequences(tokenizer, LTSM_dataset$genre_of_artist) |>
  unlist() #converts the text insto tokens (numbers that indicates the characters)

sequence_lb <- 30 #i want to look bak to 30 sequences

input_matrix <- matrix(0,nrow = length(genre_to_token)- sequence_lb, ncol = sequence_lb +1) #creates a matrix with 0
#with 31 columns, 30 observation + 1 to predict
#will be as long as the characters that are tokens

for (i in 1:( length(genre_to_token)- sequence_lb) ) {
  input_matrix[i, ] <- genre_to_token[i: (i + sequence_lb)]
}
 #i will put in the matrix the tokens of the genres squence by sequence
#first 30 +1 
#then 61 + 1 
#and so on...


X_dataset <- input_matrix[, 1:sequence_lb ] #put the first 30 column in a matrix, the lookback
Y_dataset <- input_matrix[, sequence_lb + 1] #put the last column, the predicted one 
Y_dataset <- as.array(Y_dataset) 

y_OHE <- to_categorical(Y_dataset, num_classes = length(unique(LTSM_dataset$genre_of_artist))) #it will trasform the
#dataset and trasforms into binary vectors that will be used in the model 
#it's called one-hot encoding

LTSModel <- keras_model_sequential() |>
  layer_embedding(input_dim = length(unique(LTSM_dataset$genre_of_artist)), #size of the variables
                  output_dim = 50) |> #how big should be the layer where all the neurons are connected
  layer_lstm(units = 64, dropout = 0.2, recurrent_dropout = 0.2) |>
  layer_dense(units = length(unique(LTSM_dataset$genre_of_artist)), activation = "softmax" ) #output layer
#softmax is a function that trasforms integers intoa  probability distribution

summary(LTSModel)

LTSModel |>
  compile(
    loss= "categorical_crossentropy",
    optimizer = "adam",
    metrics = c("accuracy")
  ) #we have to define the loss, optimizer and metric to measure for training 

training <- LTSModel |>
  fit(
    X_dataset, 
    y_OHE,
    epochs = 50, 
    batch_size = 120,
    validation_split = 0.2
  )
#training for 50 epochs means that i'm rebuilding the model 50 times basing on the model of the previous epoch
#the validation split is how much of the dataset i'm using for validatiion, in this case 0,20%
#i'm using a small batch size, since my computer can't handle it all. in this case 
#i'm using 120 rows at a time. 
summary(LTSModel)
plot(training)



# predicting the next value -----------------------------------------------

#to predict the next value i need the 30 last genre of the dataset, turn them into 
#an input that the model can read, with the same tokenizer.
#the result will then be converted into word with the tokenizer 
#it should give us a probability distributoin of the various genre, the highest one is predicted


predicted_genre <- function(tokenizer, LTSModel, last_genres, sequence_lb) {
  
  #trasform the text into tokens
  text_tokens <- texts_to_sequences(tokenizer, last_genres) |>
    unlist() #since it's a list we have to unlisted to put it into an array
  
  input_genre <- matrix(text_tokens, nrow = 1) #put the tokens into a matrix of 1 row
  
predicted <- LTSModel |>
  predict(input_genre) #let the model do the magic

pred_class <- which.max(predicted) -1   #see which class is the most probable
#we have to use -1 since the interface with python and r is 0 and 1
  
final_genre <- tokenizer$index_word[[as.character(pred_class)]]
#see what is the token

return(final_genre)

}

last_genres <- LTSM_dataset$genre_of_artist[ 139479 : (length(LTSM_dataset$genre_of_artist))]

predicted_genre(tokenizer = tokenizer, last_genres = last_genres, LTSModel = LTSModel, sequence_lb = sequence_lb)

#it came out indie, pop, alternative, italian, art in order of possibility


# various try to get more accuracy -----------------------------------------
#more layers #################################
LTSModel2 <- keras_model_sequential() |>
  layer_embedding(input_dim = length(unique(LTSM_dataset$genre_of_artist)), 
                  output_dim = 50) |> 
  layer_lstm(units = 64, dropout = 0.2, recurrent_dropout = 0.2, return_sequences = TRUE) |>
  layer_lstm(units = 64, dropout = 0.2, recurrent_dropout = 0.2) |>
  layer_dense(units = length(unique(LTSM_dataset$genre_of_artist)), activation = "softmax" )

#i added a second layer to see if it changes

LTSModel2 |>
  compile(
    loss= "categorical_crossentropy",
    optimizer = "adam",
    metrics = c("accuracy")
  ) 

training2 <- LTSModel2 |>
  fit(
    X_dataset, 
    y_OHE,
    epochs = 50, 
    batch_size = 120,
    validation_split = 0.2
  )


plot(training2)
summary(LTSModel2)

#i got 72.49% accuracy, worse then before...
#i reached the first time a 72.59% accuracy and 1.0764 loss  
#dropout of 0.3 ######################
#with dropout of 0.3 is worse, 72.20
LTSModel <- keras_model_sequential() |>
  layer_embedding(input_dim = length(unique(LTSM_dataset$genre_of_artist)), 
                  output_dim = 50) |> 
  layer_lstm(units = 64, dropout = 0.3, recurrent_dropout = 0.3) |>
  layer_dense(units = length(unique(LTSM_dataset$genre_of_artist)), activation = "softmax" ) 

summary(LTSModel)

LTSModel |>
  compile(
    loss= "categorical_crossentropy",
    optimizer = "adam",
    metrics = c("accuracy")
  ) 

training <- LTSModel |>
  fit(
    X_dataset, 
    y_OHE,
    epochs = 20, 
    batch_size = 128,
    validation_split = 0.2
  )

#with a batch of 128########################
#try with 128 units
LTSModel <- keras_model_sequential() |>
  layer_embedding(input_dim = length(unique(LTSM_dataset$genre_of_artist)), 
                  output_dim = 50) |> 
  layer_lstm(units = 64, dropout = 0.3, recurrent_dropout = 0.3) |>
  layer_dense(units = length(unique(LTSM_dataset$genre_of_artist)), activation = "softmax" ) 

summary(LTSModel)

LTSModel |>
  compile(
    loss= "categorical_crossentropy",
    optimizer = "adam",
    metrics = c("accuracy")
  ) 

training <- LTSModel |>
  fit(
    X_dataset, 
    y_OHE,
    epochs = 20, 
    batch_size = 128,
    validation_split = 0.2
  )
#it's 73.35% acuracy but with val_loss of 56.91% and 1.0251 loss

#with l2 regularizer############################
LTSModel <- keras_model_sequential() |>
  layer_embedding(input_dim = length(unique(LTSM_dataset$genre_of_artist)), 
                  output_dim = 50) |> 
  layer_lstm(units = 64, dropout = 0.2, kernel_regularizer = regularizer_l2(0.01)) |>
  layer_dense(units = length(unique(LTSM_dataset$genre_of_artist)), activation = "softmax" ) 

summary(LTSModel)

LTSModel |>
  compile(
    loss= "categorical_crossentropy",
    optimizer = "adam",
    metrics = c("accuracy")
  ) 

training <- LTSModel |>
  fit(
    X_dataset, 
    y_OHE,
    epochs = 20, 
    batch_size = 128,
    validation_split = 0.2
  )
#with the l2 regularization is 
#accuracy 70,94% and validation accuracy 56%

#with lower output dimensions########################
LTSModel <- keras_model_sequential() |>
  layer_embedding(input_dim = length(unique(LTSM_dataset$genre_of_artist)), 
                  output_dim = 20) |> 
  layer_lstm(units = 64, dropout = 0.2,) |>
  layer_dense(units = length(unique(LTSM_dataset$genre_of_artist)), activation = "softmax" ) 

summary(LTSModel)

LTSModel |>
  compile(
    loss= "categorical_crossentropy",
    optimizer = "adam",
    metrics = c("accuracy")
  ) 

training <- LTSModel |>
  fit(
    X_dataset, 
    y_OHE,
    epochs = 20, 
    batch_size = 128,
    validation_split = 0.2
  )
#i'm gonna try to shuffle around some things###############
#less units and recurrent dropout in ltsm layer
#regulazer in layer dense
#smaller output dimensions
#and callback for early stopping
LTSModel <- keras_model_sequential() |>
  layer_embedding(input_dim = length(unique(LTSM_dataset$genre_of_artist)), 
                  output_dim = 40 ) |> 
  layer_lstm(units = 32, dropout = 0.4, recurrent_dropout = 0.4) |>
  layer_dense(units = length(unique(LTSM_dataset$genre_of_artist)), activation = "softmax", kernel_regularizer = regularizer_l2(0.01) ) 

summary(LTSModel)

LTSModel |>
  compile(
    loss= "categorical_crossentropy",
    optimizer = "adam",
    metrics = c("accuracy")
  ) 

  
training <- LTSModel |>
  fit(
    X_dataset, 
    y_OHE,
    epochs = 50, 
    batch_size = 128,
    validation_split = 0.2,
    callbacks = callback_early_stopping(monitor = "val_loss", patience = 3, restore_best_weights = TRUE)
  )

#i got a 66.41% accuracy and 48.97% on validation
#why i did these things? well apparently the model is struggling to generalize what is learning in training to real examples,
#hence the gap of accuracies, so i need to force the model to generalize, all those things help with that. 
#less units on the ltsm layer force the model to learn the patterns and not the features of the dataset,
#the dropout turns off some neurons at random forcing the model to not rely only on some neurons, 
#a larger batch means more patters to recognize, 
#ecc.. 


#last try###########################
#since the overfitting is persisting probably the model is struggling to learns patterns because of the 
#amount of genre that i have and the long tail of the distribution of genres. 
#so i'm gonna do the best i can to force the model even more!!!

LTSModel <- keras_model_sequential() |>
  layer_embedding(input_dim = length(unique(LTSM_dataset$genre_of_artist)), 
                  output_dim = 40) |> 
  layer_spatial_dropout_1d(rate = 0.4) |> #drops entires features of the datasets 
  layer_lstm(units = 32, dropout = 0.3, recurrent_dropout = 0.3 ) |>
  layer_batch_normalization() |> #normalizes the output to avoid extreme weights in neurons
  layer_dense(units = 64, activation = "relu", kernel_regularizer = regularizer_l2(0.001)) |> #a layer of neurons thata learns
  #complex features, it uses regularization to penalize large weights to avoid overfitting and uses relu activation
  layer_dropout(0.5) |> #randomly turns off 50% of the neurons forcing the networks to learn the patterns and not memorize 
  layer_dense(units = length(unique(LTSM_dataset$genre_of_artist)), activation = "softmax" ) #layer of response

summary(LTSModel)

LTSModel |>
  compile(
    loss= loss_categorical_crossentropy(label_smoothing = 0.01),
    optimizer = optimizer_adam(learning_rate = 0.001),
    metrics = c("accuracy", metric_top_k_categorical_accuracy(k=5))
  ) 

training <- LTSModel |>
  fit(
    X_dataset, 
    y_OHE,
    epochs = 50, 
    batch_size = 128,
    validation_split = 0.2,
    callbacks = callback_early_stopping(monitor = "val_loss", patience = 3, restore_best_weights = TRUE)
  )
#69.67% on accuracy and 56.34% #without label smoothing and learning rate
#69.23% accuracy and 55.61% wuth label smoothing and learning rate BUT with top 5 80% accuracy

#this model says is indie

plot(training)
plot(LTSModel)

LTSModel |> 
  save_model_weights("LTSMmodel_genre.weights.h5")

LTSModel<- load_model("LTSMmodel_genre.h5")

