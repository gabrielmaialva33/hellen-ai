// ApexCharts Hooks for LiveView
// 2025 Color Palette: teal, sage, mint, ochre, violet, cyan

// Color palette constants
const COLORS = {
  teal: '#0d9488',      // teal-600
  tealLight: '#14b8a6', // teal-500
  sage: '#87a878',      // sage-500
  sageLight: '#a8c99b', // sage-light
  mint: '#98d4bb',      // mint-300
  ochre: '#d4a574',     // ochre-400
  violet: '#7c3aed',    // violet-600
  cyan: '#06b6d4',      // cyan-500
  emerald: '#10b981',   // emerald-500
  amber: '#f59e0b',     // amber-500
  red: '#ef4444',       // red-500
  slate: '#64748b'      // slate-500
}

// Chart palette for multiple series
const CHART_PALETTE = [COLORS.teal, COLORS.sage, COLORS.violet, COLORS.ochre, COLORS.cyan, COLORS.mint]

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
      this.el.innerHTML = '<p class="text-slate-500 dark:text-slate-400 text-center py-8">Sem dados suficientes para exibir o grafico</p>'
      return
    }

    const isDark = document.documentElement.classList.contains('dark')

    const options = {
      series: [{
        name: 'Pontuacao',
        data: data.map(d => ({
          x: new Date(d.date).getTime(),
          y: Math.round(d.score * 100)
        }))
      }],
      chart: {
        type: 'area',
        height: 280,
        fontFamily: 'Inter var, Inter, system-ui, sans-serif',
        toolbar: { show: false },
        zoom: { enabled: false },
        background: 'transparent',
        animations: {
          enabled: true,
          easing: 'easeinout',
          speed: 800
        }
      },
      colors: [COLORS.teal],
      fill: {
        type: 'gradient',
        gradient: {
          shadeIntensity: 1,
          opacityFrom: 0.5,
          opacityTo: 0.05,
          stops: [0, 90, 100],
          colorStops: [
            {
              offset: 0,
              color: COLORS.teal,
              opacity: 0.4
            },
            {
              offset: 100,
              color: COLORS.mint,
              opacity: 0.05
            }
          ]
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
            fontSize: '12px',
            fontFamily: 'Inter var, Inter, system-ui, sans-serif'
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
            fontSize: '12px',
            fontFamily: 'Inter var, Inter, system-ui, sans-serif'
          },
          formatter: (val) => `${val}%`
        }
      },
      grid: {
        borderColor: isDark ? '#334155' : '#e2e8f0',
        strokeDashArray: 4,
        padding: {
          left: 10,
          right: 10
        }
      },
      tooltip: {
        theme: isDark ? 'dark' : 'light',
        x: { format: 'dd/MM/yyyy' },
        y: {
          formatter: (val) => `${val}%`
        },
        style: {
          fontFamily: 'Inter var, Inter, system-ui, sans-serif'
        }
      },
      annotations: average > 0 ? {
        yaxis: [{
          y: Math.round(average * 100),
          borderColor: COLORS.ochre,
          borderWidth: 2,
          strokeDashArray: 5,
          label: {
            borderColor: COLORS.ochre,
            style: {
              color: '#fff',
              background: COLORS.ochre,
              fontFamily: 'Inter var, Inter, system-ui, sans-serif'
            },
            text: `Media da disciplina: ${Math.round(average * 100)}%`
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
      this.el.innerHTML = '<p class="text-slate-500 dark:text-slate-400 text-center py-8">Nenhuma competencia BNCC registrada ainda</p>'
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
        fontFamily: 'Inter var, Inter, system-ui, sans-serif',
        toolbar: { show: false },
        background: 'transparent'
      },
      colors: [COLORS.teal, COLORS.sage, COLORS.violet, COLORS.ochre, COLORS.cyan],
      plotOptions: {
        treemap: {
          distributed: true,
          enableShades: true,
          shadeIntensity: 0.5
        }
      },
      dataLabels: {
        enabled: true,
        style: {
          fontSize: '12px',
          fontFamily: 'Inter var, Inter, system-ui, sans-serif'
        },
        formatter: function(text, op) {
          return [text, op.value]
        },
        offsetY: -4
      },
      tooltip: {
        theme: isDark ? 'dark' : 'light',
        style: {
          fontFamily: 'Inter var, Inter, system-ui, sans-serif'
        }
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
      this.el.innerHTML = '<p class="text-slate-500 dark:text-slate-400 text-center py-8">Sem dados suficientes para exibir o grafico</p>'
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
        fontFamily: 'Inter var, Inter, system-ui, sans-serif',
        toolbar: { show: false },
        background: 'transparent'
      },
      colors: [COLORS.teal],
      fill: {
        type: 'gradient',
        gradient: {
          shade: 'light',
          type: 'horizontal',
          shadeIntensity: 0.25,
          gradientToColors: [COLORS.sage],
          inverseColors: false,
          opacityFrom: 1,
          opacityTo: 1,
          stops: [0, 100]
        }
      },
      plotOptions: {
        bar: {
          horizontal: true,
          borderRadius: 6,
          barHeight: '60%'
        }
      },
      dataLabels: {
        enabled: true,
        style: {
          colors: ['#fff'],
          fontFamily: 'Inter var, Inter, system-ui, sans-serif'
        }
      },
      xaxis: {
        categories: data.map(d => d.name),
        labels: {
          style: {
            colors: isDark ? '#94a3b8' : '#64748b',
            fontSize: '12px',
            fontFamily: 'Inter var, Inter, system-ui, sans-serif'
          }
        },
        axisBorder: { show: false },
        axisTicks: { show: false }
      },
      yaxis: {
        labels: {
          style: {
            colors: isDark ? '#94a3b8' : '#64748b',
            fontSize: '12px',
            fontFamily: 'Inter var, Inter, system-ui, sans-serif'
          }
        }
      },
      grid: {
        borderColor: isDark ? '#334155' : '#e2e8f0',
        strokeDashArray: 4
      },
      tooltip: {
        theme: isDark ? 'dark' : 'light',
        style: {
          fontFamily: 'Inter var, Inter, system-ui, sans-serif'
        }
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
      labels = ['Baixo', 'Medio', 'Alto', 'Critico']
      series = [
        severityData.low || 0,
        severityData.medium || 0,
        severityData.high || 0,
        severityData.critical || 0
      ]
      colors = [COLORS.emerald, COLORS.amber, COLORS.red, '#991b1b']
    } else {
      const typeData = data.by_type || {}
      labels = Object.keys(typeData).map(key => {
        const typeLabels = {
          'verbal_aggression': 'Agressao Verbal',
          'exclusion': 'Exclusao',
          'intimidation': 'Intimidacao',
          'mockery': 'Zombaria',
          'discrimination': 'Discriminacao',
          'threat': 'Ameaca',
          'inappropriate_language': 'Linguagem Impropria',
          'other': 'Outros'
        }
        return typeLabels[key] || key
      })
      series = Object.values(typeData)
      colors = CHART_PALETTE
    }

    if (series.every(v => v === 0)) {
      this.el.innerHTML = '<p class="text-slate-500 dark:text-slate-400 text-center py-8">Nenhum alerta registrado</p>'
      return
    }

    const options = {
      series,
      labels,
      colors,
      chart: {
        type: 'donut',
        height: 300,
        fontFamily: 'Inter var, Inter, system-ui, sans-serif',
        background: 'transparent'
      },
      plotOptions: {
        pie: {
          donut: {
            size: '65%',
            labels: {
              show: true,
              name: {
                show: true,
                fontSize: '14px',
                fontFamily: 'Inter var, Inter, system-ui, sans-serif',
                color: isDark ? '#e2e8f0' : '#1e293b'
              },
              value: {
                show: true,
                fontSize: '24px',
                fontFamily: 'Inter var, Inter, system-ui, sans-serif',
                fontWeight: 600,
                color: isDark ? '#e2e8f0' : '#1e293b'
              },
              total: {
                show: true,
                label: 'Total',
                fontSize: '14px',
                fontFamily: 'Inter var, Inter, system-ui, sans-serif',
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
        fontFamily: 'Inter var, Inter, system-ui, sans-serif',
        labels: {
          colors: isDark ? '#94a3b8' : '#64748b'
        }
      },
      tooltip: {
        theme: isDark ? 'dark' : 'light',
        style: {
          fontFamily: 'Inter var, Inter, system-ui, sans-serif'
        }
      },
      stroke: {
        width: 2,
        colors: [isDark ? '#1e293b' : '#ffffff']
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
      this.el.innerHTML = '<p class="text-slate-500 dark:text-slate-400 text-center py-8">Sem dados suficientes para exibir o grafico</p>'
      return
    }

    const isDark = document.documentElement.classList.contains('dark')

    let options = {
      chart: {
        type: chartType,
        height: '100%',
        fontFamily: 'Inter var, Inter, system-ui, sans-serif',
        toolbar: { show: false },
        background: 'transparent',
        stacked: chartType === 'bar' && chartData.datasets.length > 1
      },
      xaxis: {
        categories: chartData.labels,
        labels: {
          style: {
            colors: isDark ? '#94a3b8' : '#64748b',
            fontSize: '12px',
            fontFamily: 'Inter var, Inter, system-ui, sans-serif'
          }
        },
        axisBorder: { show: false },
        axisTicks: { show: false }
      },
      yaxis: {
        labels: {
          style: {
            colors: isDark ? '#94a3b8' : '#64748b',
            fontSize: '12px',
            fontFamily: 'Inter var, Inter, system-ui, sans-serif'
          }
        }
      },
      grid: {
        borderColor: isDark ? '#334155' : '#e2e8f0',
        strokeDashArray: 4,
        padding: {
          left: 10,
          right: 10
        }
      },
      tooltip: {
        theme: isDark ? 'dark' : 'light',
        style: {
          fontFamily: 'Inter var, Inter, system-ui, sans-serif'
        }
      },
      legend: {
        position: 'top',
        horizontalAlign: 'right',
        fontFamily: 'Inter var, Inter, system-ui, sans-serif',
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
          opacityTo: 0.05,
          stops: [0, 90, 100]
        }
      }
      options.colors = chartData.datasets.map((ds, i) => ds.borderColor || CHART_PALETTE[i % CHART_PALETTE.length])
    } else if (chartType === 'bar') {
      options.plotOptions = {
        bar: {
          borderRadius: 6,
          columnWidth: '60%'
        }
      }
      options.colors = chartData.datasets.map((ds, i) => ds.backgroundColor || CHART_PALETTE[i % CHART_PALETTE.length])
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

// Score Gauge - Circular progress for score display
export const ScoreGauge = {
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
    const score = parseFloat(this.el.dataset.score || '0') * 100
    const isDark = document.documentElement.classList.contains('dark')

    // Color based on score
    let color = COLORS.red
    if (score >= 80) color = COLORS.teal
    else if (score >= 60) color = COLORS.sage
    else if (score >= 40) color = COLORS.ochre

    const options = {
      series: [Math.round(score)],
      chart: {
        type: 'radialBar',
        height: 200,
        fontFamily: 'Inter var, Inter, system-ui, sans-serif',
        background: 'transparent',
        sparkline: {
          enabled: true
        }
      },
      colors: [color],
      plotOptions: {
        radialBar: {
          startAngle: -135,
          endAngle: 135,
          hollow: {
            size: '70%'
          },
          track: {
            background: isDark ? '#334155' : '#e2e8f0',
            strokeWidth: '100%',
            margin: 0
          },
          dataLabels: {
            name: {
              show: false
            },
            value: {
              fontSize: '32px',
              fontWeight: 700,
              fontFamily: 'Inter var, Inter, system-ui, sans-serif',
              color: isDark ? '#e2e8f0' : '#1e293b',
              offsetY: 10,
              formatter: (val) => `${val}%`
            }
          }
        }
      },
      stroke: {
        lineCap: 'round'
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
