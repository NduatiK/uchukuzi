const isDevelopment =  (process.env.NODE_ENV !== 'production')
console.log("isDevelopment", isDevelopment)

export default { isDevelopment }