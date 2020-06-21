
const loadChartLib = () => {
    if (typeof ApexCharts !== typeof undefined) {
        return Promise.resolve()
    }
    return new Promise((resolve, reject) => {
        const script = document.createElement('script')
        script.type = 'text/javascript'
        script.onload = resolve
        script.onerror = reject
        document.getElementsByTagName('head')[0].appendChild(script)
        script.src = "/js/chart.min.js"

    })
}


function renderChart(dates, y, statistics) {
    if (dates.length == 0) {
        return
    }

    const dateCount = dates.length
    const { runningAverage, consumptionOnDate } = y


    loadChartLib()
        .then(() => {


            var runningAverageSeries = []
            var allTimeAverage = []
            var consumptionOnDateSeries = []

            for (var i = 0; i < dateCount; i++) {
                if (i != dateCount - 1) {
                    runningAverageSeries.push([dates[i], runningAverage[i]])
                } else {
                    runningAverageSeries.push([dates[i], null])
                }

                consumptionOnDateSeries.push([dates[i], consumptionOnDate[i]])

                if (statistics) {
                    allTimeAverage.push([dates[i], statistics.mean])
                }

            }


            const maximumConsumption = Math.max(...consumptionOnDate, ...runningAverage)

            var annotations = undefined

            if (statistics) {
                annotations = {
                    yaxis: [{
                        y: statistics.mean + 2 * statistics.stdDev,
                        y2: maximumConsumption + statistics.stdDev,
                        borderColor: '#000',
                        fillColor: '#Ff0000',
                        opacity: 0.3,
                        label: {
                            borderColor: '#333',
                            style: {
                                fontSize: '12px',
                                color: '#ddd',
                                background: '#fff',
                            },
                            text: 'High',
                            offsetY: 37,
                            offsetX: 30,
                        }
                    }]
                }
            }


            var options = {
                colors: ["#594FEE", '#333', "#00b2c3"],
                series: [
                    {
                        name: 'Consumption Rate',
                        type: 'column',
                        data: consumptionOnDateSeries
                    },
                    {
                        name: 'All time average',
                        data: allTimeAverage
                    }, {
                        name: 'Running Average',
                        data: runningAverageSeries
                    }],

                annotations: annotations,
                chart: {
                    height: 350,
                    type: 'line',
                    zoom: {
                        type: 'x',
                        enabled: true,
                    },
                    animations: {
                        enabled: false
                    }
                },
                stroke: {
                    width: [2, 2, 4],
                    curve: 'smooth'
                },
                markers: {
                    size: [5, 0, 5],
                    
                    hover: {
                        size: 7
                    }
                },
                labels: dates,
                xaxis: {
                    type: 'datetime',
                },
                yaxis: {
                    forceNiceScale: true,
                    min: 0,
                    // max: Math.round(Math.max(...consumptionOnDate)) + 1,
                    title: {
                        text: 'Fuel Consumption (Litres per 100 km)',
                    }
                    , labels: {
                        formatter: function (val, index) {
                            if (val) {
                                return val.toFixed(2);
                            } else {
                                return val
                            }
                        }
                    }
                },
                // fill: {
                //     opacity: 1,
                //     type: 'solid'
                // }
            }

            var myChart = new ApexCharts(document.querySelector("#chart"), options)

            myChart.render()

            myChart.hideSeries('All time average')

        })
}

export { renderChart }