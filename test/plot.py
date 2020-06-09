import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import time
import os
from pickle import dump, load

models_dir = "./models"


def model_name(name):
    return '{}/{}.pkl' \
        .format(models_dir, name) \
        .replace("b'", "") \
        .replace("'", "")


def predict(name, time):

    try:
        # When predicting,
        # find the model for the tile
        model = load(open(model_name(name), 'rb'))
    except Exception as e:
        print(e)
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


def plot_for(model):
    # print(__doc__)

    X = np.random.rand(100) * 23
    Y = [predict(model, time) for time in X]

    plt.scatter(X, Y, color='m', lw=2,
             label="Prediction for {}".format(model))

    plt.legend(loc='upper center', bbox_to_anchor=(0.5, 1.1),
               ncol=1, fancybox=True, shadow=True)

    plt.show()


plot_for("HRH6LIEME44BREIMDHLM4ORKKG5DBLEW")
