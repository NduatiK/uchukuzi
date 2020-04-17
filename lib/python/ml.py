import warnings
from sklearn.exceptions import DataConversionWarning
warnings.filterwarnings("ignore", category=DataConversionWarning)

from pickle import dump, load
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVR
import pandas as pd


models_dir = "./models"


def model_name(name):
    return '{}/{}.pkl'.format(models_dir, name)


def learn(name, data):

    data = [list(row) for row in data]
    data = pd.DataFrame(data)
    data = data[((data[1] - data[1].mean()) / data[1].std()).abs() < 3]

    if data.size < 10:

        dump(("ave", data[1].mean()), open(model_name(name), 'wb'))
    else:

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
    model = load(open(model_name(name), 'rb'))

    try:
        (_, average) = model
        return average
    except:
        (sc_X, sc_y, svr) = model

        time = sc_X.transform(time)
        scaled_prediction = svr.predict([time])[0]
        return sc_y.inverse_transform(scaled_prediction)
