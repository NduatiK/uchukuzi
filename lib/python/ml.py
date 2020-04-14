import pandas as pd
from sklearn.svm import SVR
from sklearn.preprocessing import StandardScaler
from pickle import dump, load


models_dir = "./models"

def model_name(name):
    return '{}/{}.pkl'.format(models_dir, name)

def learn(name, data):
    data = [list(row) for row in data]
    data = pd.DataFrame(data)
    data = data[((data[1] - data[1].mean()) / data[1].std()).abs() < 3]

    sc_X = StandardScaler()
    sc_y = StandardScaler()

    X = sc_X.fit_transform(data.iloc[:, 0:-1])
    y = sc_y.fit_transform(data.iloc[:, -1:])

    svr = SVR(kernel='rbf', C=100, gamma=0.1, epsilon=.1)
    # svr_lin = SVR(kernel='linear', C=100, gamma='auto')
    # svr_poly = SVR(kernel='poly', C=100, gamma='auto', degree=2, epsilon=.1,
    #             coef0=1)

    svr = svr.fit(X, y)
    try:
        import os
        os.mkdir(models_dir)
    except:
        pass

    # Path(models_dir).mkdir(exist_ok=True)

    dump((sc_X, sc_y, svr), open(model_name(name), 'wb'))


def predict(name, time):
    (sc_X, sc_y, svr) = load(open(model_name(name), 'rb'))

    time = sc_X.transform(time)
    scaled_prediction = svr.predict([time])[0]
    return sc_y.inverse_transform(scaled_prediction)
