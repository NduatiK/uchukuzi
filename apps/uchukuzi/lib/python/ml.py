import pandas as pd
from sklearn.svm import SVR
from sklearn.preprocessing import StandardScaler
from pickle import dump, load
import warnings
from sklearn.exceptions import DataConversionWarning
warnings.filterwarnings("ignore", category=DataConversionWarning)


models_dir = "./models"


def model_name(name):
    return '{}/{}.pkl'.format(models_dir, name)


def learn(name, data):

    data = [list(row) for row in data]
    data = pd.DataFrame(data)

    # Remove outliers
    # - Outliers are records that are more than 3
    # standard deviations from the mean
    data = data[((data[1] - data[1].mean()) / data[1].std()).abs() < 3]

    if data.size < 10:
        # if we have insufficient data to make it
        # worthwhile to build a model, then calulate
        # the average and store that
        dump(("ave", data[1].mean()), open(model_name(name), 'wb'))
    else:
        # otherwise scale the data,
        # build a support vector regressor
        # and store store the transformer and estimators

        sc_X = StandardScaler()
        sc_y = StandardScaler()

        X = sc_X.fit_transform(data.iloc[:, 0:-1])
        y = sc_y.fit_transform(data.iloc[:, -1:])

        svr = SVR(kernel='rbf', C=100, gamma=0.1, epsilon=.1)

        svr = svr.fit(X, y.ravel())

        try:
            import os
            os.mkdir(models_dir)
        except:
            pass

        dump((sc_X, sc_y, svr), open(model_name(name), 'wb'))


def predict(name, time):
    try:
        # When predicting,
        # find the model for the tile
        model = load(open(model_name(name), 'rb'))
    except:
        # if no model is found, assume a speed of 16km/h (500m/8min)
        return 60 * 8

    try:
        # It may be an average
        # try to pattern match on that
        (_, average) = model
        return average
    except:
        # or it may be the trained scalers and estimator
        (sc_X, sc_y, svr) = model

        time = sc_X.transform([[time]])
        scaled_prediction = svr.predict(time)
        prediction = sc_y.inverse_transform(scaled_prediction)
        return float(prediction[0])
