import { sleep } from "./sleep"
import { Colors } from "./colors";

interface CustomWindow extends Window {
    ApexCharts: any;
}
declare let window: CustomWindow;

const loadChartLib = () => {
    if (typeof window.ApexCharts !== typeof undefined) {
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



function renderChart({ x, y, statistics }: {
    x: number[];
    y: { consumptionOnDate: number[]; runningAverage: number[] };
    statistics: { stdDev: number; mean: number } | null
}) {
    const dates = x


    const dateCount = dates.length
    const { runningAverage, consumptionOnDate } = y

    sleep(200)
        .then(loadChartLib)
        .then(() => {
            const Charts = window.ApexCharts
            if (!Charts) { return }

            var runningAverageSeries: [number, (number | null)][] = []
            var allTimeAverage: [number, (number | null)][] = []
            var consumptionOnDateSeries: [number, number][] = []

            for (var i = 0; i < dateCount; i++) {
                // if (i != dateCount - 1) {
                    if (statistics) {
                        allTimeAverage.push([dates[i], statistics.mean])
                    }
                    runningAverageSeries.push([dates[i], runningAverage[i]])
                // } else {
                //     if (statistics) {
                //         allTimeAverage.push([dates[i], null])
                //     }
                //     runningAverageSeries.push([dates[i], null])
                // }

                consumptionOnDateSeries.push([dates[i], consumptionOnDate[i]])
            }

            const maximumConsumption = Math.max(...consumptionOnDate, ...runningAverage)

            var annotations = undefined

            if (statistics) {
                annotations = {
                    yaxis: [{
                        y: statistics.mean + 2 * statistics.stdDev,
                        y2: maximumConsumption + maximumConsumption,
                        borderColor: '#000',
                        fillColor: '#ff0000',
                        opacity: 0.3,

                    },
                    {
                        y: statistics.mean + 2 * statistics.stdDev,
                        borderColor: '#000',
                        fillColor: '#000',
                        opacity: 0,
                        label: {
                            borderColor: '#333',
                            style: {
                                fontSize: '12px',
                                color: '#ddd',
                                background: '#fff',
                            },
                            text: 'High',

                        }
                    }]
                }
            }

            var options = {
                noData: {
                    text: "No Chart Data Available",
                    style: {
                        color: '#ddd',
                        fontSize: 30
                    }
                },
                colors: [
                    function ({ value } : {value: number}) {
                        if (statistics && value > statistics.mean + 2 * statistics.stdDev) {
                            return Colors.errorRed
                        } else {
                            return Colors.purple
                        }
                    },
                    function ({ }) {
                        return "#333"
                    },
                    function ({ }) {
                        return Colors.tealGreen
                    }],
                series: [
                    {
                        name: 'Consumption Rate',
                        type: 'column',
                        data: consumptionOnDateSeries
                    },
                    {
                        name: 'All time average',
                        data: allTimeAverage
                    },
                    {
                        name: 'Running Average',
                        data: runningAverageSeries
                    },
                ],

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
                        formatter: function (val: number, index: number) {
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

            const domEl = document.querySelector("#chart")
            if (!domEl) {
                return
            }

            var myChart = new Charts(domEl, options)

            myChart.render()

            myChart.hideSeries('All time average')

        })
}

export { renderChart }