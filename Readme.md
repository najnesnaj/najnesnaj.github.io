# Documenting projects
 

sphinx: make html

copy build/html/* under /static/docs/projectname


update config.toml
[[menu.main]]
  name = 'RAGflow Docs'
  url = '/docs/projectname/'
  weight = 5

