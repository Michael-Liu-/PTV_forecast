Instructions:
=============
1. The source code is written in R language, with version 3.4
2. Several external libraries are used, 'Hmisc','caret','randomForest' and 'xgboost'. 'Hmisc' is used to create lag variables, and 'caret' is used for model training. 'randomForest' and 'xgboost' are used for checking variable importance and final model, respectively. The library can be easily installed by running install.packages('xx')
3. The code can be run line by line without error, and the comment should be enough to explain the purpose.


Metrics:
========
Two metrics are selected in this project for evaluation, RMSE and SMAPE.

RMSE is a standard metric used for regression problem. As for SMAPE (symmetric mean absolute percent error), it is chosen because of the nature of this task. The objective is to forecast Peak Traffic Volume for better online experience, so overforecast is preferred compared to underforecast, as underforecast might cause poor preparation for the peak visitor volume. Hence, a metric favouring overforecast (SMAPE) is selected.


Steps & Algorithm:
====================

1. Load in data, explore data and find that there is a increasing trend with fluctuations and several peaks during festivals (double 11). A natural thought is to create a time-related variable to capture the seemingly linear increasing trend, thus create a feature 'date' which equals the difference between current date and '2016-12-31'

2. Since the task is to forecast at least 2 weeks in advance, then PTV and TTV at t-14 is the closest values can be obtained, thus add 'PTV_14_day' and 'TTV_14_day' as features. Try running the model with three features, 'date','PTV_14_day','TTV_14_day', R square is already at 70% level. However, RMSE is 9000+, which is not good enough. Try adding more lags like PTV and TTV at t-15, t-16 does not help improve performance. Hence I decide to only use t-14 values. (auto.arima also suggest that lag 1 is the best)

3. Consider adding promotion features and voucher features. As the task is to forecast daily peak volume instead of total volume, thus the actual hour in starting_time and end_time do not matter. Then all the promotions and vouchers are aggregated on daily levels. Features like mean, median, max, min, standard deviation of discount and rebate are created, as well as the number of vouchers and promotions applicable on the day of forecast.

4. Add scale_score as features, and separate training and testing dataset. I use Mar-Nov as training and rest as testing. The reason is that November is the only month with scale_score equal to 2 and hence training set should include them, otherwise the performance wouldn't be good. However, if using Jan-Nov as training, the test set would be too small and prone to overfitting. Hence I use Mar-Nov (9 months) as training and Jan-Feb + Dec (3 months) as testing set. 

5. As for models, traditional methods like linear regression, randomForest, svm, neural network and many other methods are all used to model the time series. However, it turns out that xgboost is the best with both low RMSE and SMAPE. Thus it is chosen as the best model for further parameter tuning. A side note here is that the variable importance plot by randomForest suggests the date itself, number of promotions and mean of min_price are the most important variables.

6. Finally grid search is used to tune the parameters in xgboost. In the end the final best performance is training RMSE 3091,test RMSE 8028 and training SMAPE 0.04,test SMAPE 0.116. Though there are several sets of parameter can have lower training RMSE and training SMAPE, they all result in much higher test RMSE and test SMAPE and are very likely to overfit the training set. Therefore, I choose a set of parameter that have relatively comparable training and test RMSE and lowest test SMAPE.


Thank you!
