## Shopee mini project
library('Hmisc')
library('caret')
library('randomForest')

set.seed(123)

setwd("~/Downloads/Shopee Interview")
data_ptv = read.csv('PTV_TTV.csv', stringsAsFactors = F)
data_pro = read.csv('promotions.csv', stringsAsFactors = F)
data_vou = read.csv('vouchers.csv', stringsAsFactors = F)

## The first column seems useless, just index
data_ptv$X = NULL
data_pro$X = NULL
data_vou$X = NULL
## Convert date to Date format (more standard)
data_ptv$date = as.Date(data_ptv$date, format = "%d/%m/%y")
data_pro$start_time = as.POSIXct(data_pro$start_time, format = "%d/%m/%y %H:%M")
data_pro$end_time = as.POSIXct(data_pro$end_time, format = "%d/%m/%y %H:%M")

## Explore PTV and TTV time-series
## A clear increasing trend can be observed
plot(data_ptv$date, data_ptv$PTV, type = 'l', xlab = 'Date', ylab = 'PTV')


## Since the task is to predict daily PTV, the exact hour of voucher and promotion doesn't seem to matter
## It might be better to aggregate the features on daily level
data_pro$start_time = as.Date(substr(data_pro$start_time,1,10),format = '%Y-%m-%d')
data_pro$end_time = as.Date(substr(data_pro$end_time,1,10), format = '%Y-%m-%d')
data_vou$start_time = as.Date(substr(data_vou$start_time,1,10),format = '%Y-%m-%d')
data_vou$end_time = as.Date(substr(data_vou$end_time,1,10), format = '%Y-%m-%d')


## Create daily promotion and voucher features
## Function to get simple statistics about daily aggregated features
create_feature <- function(vector){
  return (c(mean(vector), median(vector), max(vector), min(vector), sd(vector)))
}

create_colnames <- function(feature_name){
  return(c(paste(feature_name,'mean',sep = '_'),paste(feature_name,'median',sep = '_'),
           paste(feature_name,'max',sep = '_'),paste(feature_name,'min',sep = '_'),
           paste(feature_name,'sd',sep = '_')))
}

create_promotion_voucher_features <- function(data_ptv){
  pro_features = data.frame()
  vou_features = data.frame()
  for(i in 1:nrow(data_ptv)){
    current_date = data_ptv$date[i]
    ## search through the promotion dataset to find all promotions happen on current_date
    ## 1. start_time before current_date 2. end_time after current_date 
    current_promo_set = data_pro[data_pro$start_time <= current_date & data_pro$end_time >= current_date,]
    num_pro = nrow(current_promo_set)
    if(num_pro == 0) {
      pro_features = rbind(pro_features,rep(0,16))
    } else {
      price_feature = create_feature(current_promo_set$promotion_price)
      rebate_feature = create_feature(current_promo_set$rebate)
      pro_discount_feature = create_feature(current_promo_set$discount_percent)
      pro_features = rbind(pro_features, c(num_pro, price_feature, rebate_feature, pro_discount_feature))
    }
    ## search through the voucher dataset to find all voucher happen on current_date
    ## 1. start_time before current_date 2. end_time after current_date 
    current_vou_set = data_vou[data_vou$start_time <= current_date & data_vou$end_time >= current_date,]
    num_vou = nrow(current_vou_set)
    if(num_vou == 0){
      vou_features = rbind(vou_features, rep(0,21))
    } else {
      vou_discount_features = create_feature(current_vou_set$discount)
      min_price_features = create_feature(current_vou_set$min_price)
      value_features = create_feature(current_vou_set$value)
      usage_features = create_feature(current_vou_set$usage_limit)
      vou_features = rbind(vou_features, c(num_vou, vou_discount_features, min_price_features, value_features, usage_features))
    }
  }
  colnames(pro_features) = c('num_pro', create_colnames('price'), create_colnames('rebate'), create_colnames('pro_discount'))
  colnames(vou_features) = c('num_vou', create_colnames('vou_discount'), create_colnames('min_price'), create_colnames('value'),
                             create_colnames('usage'))
  return(cbind(pro_features, vou_features))
}




## At least two weeks forecast
data_ptv0 = data_ptv
data_ptv0$PTV_14_day = Lag(data_ptv0$PTV, shift = 14)
data_ptv0$TTV_14_day = Lag(data_ptv0$TTV, shift = 14)
 
data_ptv0 = cbind(data_ptv0, create_promotion_voucher_features(data_ptv0))


## Add scale score for festival importance
data_ptv0$scale_score = rep(0,nrow(data_ptv0))
data_ptv0$scale_score[data_ptv0$date >= '2017-01-14' & data_ptv0$date <= '2017-01-27'] = 1
data_ptv0$scale_score[data_ptv0$date >= '2017-11-08' & data_ptv0$date <= '2017-11-11'] = 2
data_ptv0$scale_score[data_ptv0$date >= '2017-12-21' & data_ptv0$date <= '2017-12-25'] = 1
data_ptv0$scale_score = as.factor(data_ptv0$scale_score)

## Seperate training and testing, also create date difference as a feature
data_ptv0 = na.omit(data_ptv0)
data_ptv0$TTV = NULL
train_index = data_ptv0$date >= '2017-04-01' & data_ptv0$date < '2017-12-01'  
data_ptv0$date = data_ptv0$date - as.Date('2016-12-31')

ptv_train = data_ptv0[train_index,]
ptv_test = data_ptv0[!train_index,]

## check variable importance
model.rf = randomForest(PTV ~., data = ptv_train)
varImpPlot(model.rf)

## SAMPE function to evaluate the performance
smape <- function(predicted, actual){
  return( mean(2*abs(predicted - actual)/(predicted + actual), na.rm=TRUE))
}

smapeSummary <- function(data,lev = NULL,model = NULL) {
  out <- smape(data$obs, data$pred)  
  names(out) <- c('smape')
  out
}

fitControl <- trainControl(## 10-fold CV
  method = "repeatedcv",
  number = 10,
  repeats = 5,
  summaryFunction = smapeSummary
)

xgb_grid = expand.grid(
  nrounds = 1000,
  eta = c(0.05,0.03,0.01),
  max_depth = c(2,3),
  gamma = 0,             
  colsample_bytree = 1,    
  min_child_weight = 1, 
  subsample = c(0.7,0.8)
)


## caret model training and tuning
model.fit = train(PTV~., data = ptv_train, method = 'xgbTree', trainControl = fitControl,  tuneGrid = xgb_grid)

## Check training and testing
predicted = predict(model.fit, data_ptv0)
train_predicted = predict(model.fit, ptv_train)
test_predicted = predict(model.fit, ptv_test)

## Evaluate model performance
RMSE(train_predicted, ptv_train$PTV)
RMSE(test_predicted, ptv_test$PTV)
smape(train_predicted, ptv_train$PTV)
smape(test_predicted, ptv_test$PTV)

## Check test residual distribution
hist(test_predicted-ptv_test$PTV, breaks = 20)

## Plot predicted value and actual value
plot(range(data_ptv0$date), range(c(data_ptv0$PTV, predicted)), type = 'n', xlab = 'Date', ylab = 'PTV')
lines(data_ptv0$date, data_ptv0$PTV, col = 'red')
lines(data_ptv0$date, predicted, col = 'blue')
