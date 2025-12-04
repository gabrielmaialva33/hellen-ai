// ApexCharts Hooks for LiveView
// Provides reactive chart rendering with data from the server

export const ScoreChart = {
  mounted() {
    this.chart = null
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  renderChart() {
    const data = JSON.parse(this.el.dataset.chartData || '[]')
    const average = parseFloat(this.el.dataset.average || '0')

    if (data.length === 0) {
      this.el.innerHTML = '<p class="text-gray-500 text-center py-8">Sem dados suficientes para exibir o gráfico</p>'
      return
    }

    const isDark = document.documentElement.classList.contains('dark')

    const options = {
      series: [{
        name: 'Pontuação',
        data: data.map(d => ({
          x: new Date(d.date).getTime(),
          y: Math.round(d.score * 100)
        }))
      }],
      chart: {
        type: 'area',
        height: 280,
        fontFamily: 'inherit',
        toolbar: { show: false },
        zoom: { enabled: false },
        background: 'transparent',
        animations: {
          enabled: true,
          easing: 'easeinout',
          speed: 800
        }
      },
      colors: ['#6366f1'],
      fill: {
        type: 'gradient',
        gradient: {
          shadeIntensity: 1,
          opacityFrom: 0.5,
          opacityTo: 0.1,
          stops: [0, 90, 100]
        }
      },
      stroke: {
        curve: 'smooth',
        width: 3
      },
      dataLabels: { enabled: false },
      xaxis: {
        type: 'datetime',
        labels: {
          style: {
            colors: isDark ? '#94a3b8' : '#64748b',
            fontSize: '12px'
          },
          datetimeFormatter: {
            day: 'dd/MM'
          }
        },
        axisBorder: { show: false },
        axisTicks: { show: false }
      },
      yaxis: {
        min: 0,
        max: 100,
        labels: {
          style: {
            colors: isDark ? '#94a3b8' : '#64748b',
            fontSize: '12px'
          },
          formatter: (val) => `${val}%`
        }
      },
      grid: {
        borderColor: isDark ? '#334155' : '#e2e8f0',
        strokeDashArray: 4
      },
      tooltip: {
        theme: isDark ? 'dark' : 'light',
        x: { format: 'dd/MM/yyyy' },
        y: {
          formatter: (val) => `${val}%`
        }
      },
      annotations: average > 0 ? {
        yaxis: [{
          y: Math.round(average * 100),
          borderColor: '#f59e0b',
          borderWidth: 2,
          strokeDashArray: 5,
          label: {
            borderColor: '#f59e0b',
            style: {
              color: '#fff',
              background: '#f59e0b'
            },
            text: `Média da disciplina: ${Math.round(average * 100)}%`
          }
        }]
      } : {}
    }

    if (this.chart) {
      this.chart.updateOptions(options)
    } else {
      this.chart = new ApexCharts(this.el, options)
      this.chart.render()
    }
  }
}

export const BnccHeatmap = {
  mounted() {
    this.chart = null
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  renderChart() {
    const data = JSON.parse(this.el.dataset.chartData || '[]')

    if (data.length === 0) {
      this.el.innerHTML = '<p class="text-gray-500 text-center py-8">Nenhuma competência BNCC registrada ainda</p>'
      return
    }

    const isDark = document.documentElement.classList.contains('dark')

    // Group by category (first part of code)
    const categories = {}
    data.forEach(item => {
      const category = item.code.split('.')[0] || 'Outros'
      if (!categories[category]) categories[category] = []
      categories[category].push({
        x: item.code,
        y: item.count
      })
    })

    const series = Object.entries(categories).map(([name, data]) => ({
      name,
      data
    }))

    const options = {
      series,
      chart: {
        type: 'treemap',
        height: 350,
        fontFamily: 'inherit',
        toolbar: { show: false },
        background: 'transparent'
      },
      colors: ['#6366f1', '#8b5cf6', '#a855f7', '#d946ef', '#ec4899'],
      plotOptions: {
        treemap: {
          distributed: true,
          enableShades: true
        }
      },
      dataLabels: {
        enabled: true,
        style: {
          fontSize: '12px'
        },
        formatter: function(text, op) {
          return [text, op.value]
        },
        offsetY: -4
      },
      tooltip: {
        theme: isDark ? 'dark' : 'light'
      }
    }

    if (this.chart) {
      this.chart.updateOptions(options)
    } else {
      this.chart = new ApexCharts(this.el, options)
      this.chart.render()
    }
  }
}

export const CoordinatorBarChart = {
  mounted() {
    this.chart = null
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  renderChart() {
    const data = JSON.parse(this.el.dataset.chartData || '[]')

    if (data.length === 0) {
      this.el.innerHTML = '<p class="text-gray-500 dark:text-gray-400 text-center py-8">Sem dados suficientes para exibir o grafico</p>'
      return
    }

    const isDark = document.documentElement.classList.contains('dark')

    const options = {
      series: [{
        name: 'Aulas',
        data: data.map(d => d.lessons)
      }],
      chart: {
        type: 'bar',
        height: 280,
        fontFamily: 'inherit',
        toolbar: { show: false },
        background: 'transparent'
      },
      colors: ['#6366f1'],
      plotOptions: {
        bar: {
          horizontal: true,
          borderRadius: 4,
          barHeight: '60%'
        }
      },
      dataLabels: {
        enabled: true,
        style: {
          colors: ['#fff']
        }
      },
      xaxis: {
        categories: data.map(d => d.name),
        labels: {
          style: {
            colors: isDark ? '#94a3b8' : '#64748b',
            fontSize: '12px'
          }
        },
        axisBorder: { show: false },
        axisTicks: { show: false }
      },
      yaxis: {
        labels: {
          style: {
            colors: isDark ? '#94a3b8' : '#64748b',
            fontSize: '12px'
          }
        }
      },
      grid: {
        borderColor: isDark ? '#334155' : '#e2e8f0',
        strokeDashArray: 4
      },
      tooltip: {
        theme: isDark ? 'dark' : 'light'
      }
    }

    if (this.chart) {
      this.chart.updateOptions(options)
    } else {
      this.chart = new ApexCharts(this.el, options)
      this.chart.render()
    }
  }
}

export const AlertsChart = {
  mounted() {
    this.chart = null
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  renderChart() {
    const data = JSON.parse(this.el.dataset.chartData || '{}')
    const chartType = this.el.dataset.chartType || 'severity'

    const isDark = document.documentElement.classList.contains('dark')

    let series, labels, colors

    if (chartType === 'severity') {
      const severityData = data.by_severity || {}
      labels = ['Baixo', 'Médio', 'Alto', 'Crítico']
      series = [
        severityData.low || 0,
        severityData.medium || 0,
        severityData.high || 0,
        severityData.critical || 0
      ]
      colors = ['#22c55e', '#f59e0b', '#ef4444', '#991b1b']
    } else {
      const typeData = data.by_type || {}
      labels = Object.keys(typeData).map(key => {
        const typeLabels = {
          'verbal_aggression': 'Agressão Verbal',
          'exclusion': 'Exclusão',
          'intimidation': 'Intimidação',
          'mockery': 'Zombaria',
          'discrimination': 'Discriminação',
          'threat': 'Ameaça',
          'inappropriate_language': 'Linguagem Imprópria',
          'other': 'Outros'
        }
        return typeLabels[key] || key
      })
      series = Object.values(typeData)
      colors = ['#6366f1', '#8b5cf6', '#a855f7', '#d946ef', '#ec4899', '#f43f5e', '#f97316', '#84cc16']
    }

    if (series.every(v => v === 0)) {
      this.el.innerHTML = '<p class="text-gray-500 text-center py-8">Nenhum alerta registrado</p>'
      return
    }

    const options = {
      series,
      labels,
      colors,
      chart: {
        type: 'donut',
        height: 300,
        fontFamily: 'inherit',
        background: 'transparent'
      },
      plotOptions: {
        pie: {
          donut: {
            size: '65%',
            labels: {
              show: true,
              total: {
                show: true,
                label: 'Total',
                color: isDark ? '#94a3b8' : '#64748b'
              }
            }
          }
        }
      },
      dataLabels: {
        enabled: false
      },
      legend: {
        position: 'bottom',
        labels: {
          colors: isDark ? '#94a3b8' : '#64748b'
        }
      },
      tooltip: {
        theme: isDark ? 'dark' : 'light'
      }
    }

    if (this.chart) {
      this.chart.updateOptions(options)
    } else {
      this.chart = new ApexCharts(this.el, options)
      this.chart.render()
    }
  }
}

// Generic Analytics Chart - supports line, bar, and stacked bar
export const AnalyticsChart = {
  mounted() {
    this.chart = null
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  renderChart() {
    const chartData = JSON.parse(this.el.dataset.chart || '{}')
    const chartType = this.el.dataset.type || 'line'

    if (!chartData.labels || chartData.labels.length === 0) {
      this.el.innerHTML = '<p class="text-gray-500 dark:text-gray-400 text-center py-8">Sem dados suficientes para exibir o grafico</p>'
      return
    }

    const isDark = document.documentElement.classList.contains('dark')

    let options = {
      chart: {
        type: chartType,
        height: '100%',
        fontFamily: 'inherit',
        toolbar: { show: false },
        background: 'transparent',
        stacked: chartType === 'bar' && chartData.datasets.length > 1
      },
      xaxis: {
        categories: chartData.labels,
        labels: {
          style: {
            colors: isDark ? '#94a3b8' : '#64748b',
            fontSize: '12px'
          }
        },
        axisBorder: { show: false },
        axisTicks: { show: false }
      },
      yaxis: {
        labels: {
          style: {
            colors: isDark ? '#94a3b8' : '#64748b',
            fontSize: '12px'
          }
        }
      },
      grid: {
        borderColor: isDark ? '#334155' : '#e2e8f0',
        strokeDashArray: 4
      },
      tooltip: {
        theme: isDark ? 'dark' : 'light'
      },
      legend: {
        position: 'top',
        horizontalAlign: 'right',
        labels: {
          colors: isDark ? '#94a3b8' : '#64748b'
        }
      }
    }

    // Build series from datasets
    options.series = chartData.datasets.map(ds => ({
      name: ds.label,
      data: ds.data
    }))

    // Chart type specific options
    if (chartType === 'line') {
      options.stroke = {
        curve: 'smooth',
        width: 3
      }
      options.fill = {
        type: 'gradient',
        gradient: {
          shadeIntensity: 1,
          opacityFrom: 0.4,
          opacityTo: 0.1,
          stops: [0, 90, 100]
        }
      }
      options.colors = chartData.datasets.map(ds => ds.borderColor || '#6366f1')
    } else if (chartType === 'bar') {
      options.plotOptions = {
        bar: {
          borderRadius: 4,
          columnWidth: '60%'
        }
      }
      options.colors = chartData.datasets.map(ds => ds.backgroundColor || '#6366f1')
      options.dataLabels = { enabled: false }
    }

    if (this.chart) {
      this.chart.updateOptions(options)
    } else {
      this.chart = new ApexCharts(this.el, options)
      this.chart.render()
    }
  }
}
