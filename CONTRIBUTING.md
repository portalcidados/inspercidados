# Contributing to cidadosSP

Thank you for your interest in contributing to the cidadosSP project! This guide will help you understand how to add new datasets or improve existing ones.

## 🎯 Our Goals

- Standardize access to São Paulo public datasets
- Ensure reproducibility of data processing
- Provide clear documentation and citations
- Maintain high data quality standards

## 📋 Before You Start

### Prerequisites
- R (>= 4.0.0)
- Git and GitHub account
- Familiarity with the tidyverse
- Access to the original data source

### Getting Access
1. Contact the Insper Cidades team at cidades@insper.edu.br
2. Request access to:
   - The GitHub repository
   - Insper's Dataverse
   - Portal CiDados credentials (if needed)

## 🔄 Workflow for Adding a New Dataset

### 1. Initial Setup

```bash
# Clone the repository
git clone https://github.com/insper-cidades/cidadosSP.git
cd cidadosSP

# Create a new branch
git checkout -b add-dataset-name
```

### 2. Create Dataset Folder

```bash
# Copy the template
cp -r data-raw/_template data-raw/your_dataset_name

# Navigate to your dataset folder
cd data-raw/your_dataset_name

# Initialize renv for reproducibility
R -e "renv::init()"
```

### 3. Customize the Scripts

Each dataset requires four main scripts:

1. **`01_download.R`**: Obtain raw data
   - Document the source URL
   - Implement retry logic for large files
   - Save raw files to `raw/` subdirectory

2. **`02_clean.R`**: Standardize the data
   - Use snake_case for column names
   - Handle encoding issues (UTF-8)
   - Document all transformations

3. **`03_validate.R`**: Quality assurance
   - Check for completeness
   - Validate geographic codes
   - Identify outliers and inconsistencies

4. **`04_export.R`**: Generate final outputs
   - Export to parquet format
   - Create metadata JSON
   - Generate citation files

### 4. Documentation Requirements

Update the `README.md` in your dataset folder with:
- Dataset description and importance
- Source information and license
- Temporal and geographic coverage
- Variable descriptions
- Processing pipeline explanation
- Known issues or limitations

### 5. Metadata Standards

Your `metadata.json` must include:
```json
{
  "id": "dataset_id",
  "title": "Full Dataset Title",
  "description": "Clear description",
  "authors": ["Author Name"],
  "contact": "email@insper.edu.br",
  "categories": ["Category1", "Category2"],
  "geographic_coverage": "São Paulo - SP",
  "temporal_coverage": "2010-2024",
  "producer": "Original Producer",
  "contribution": "Your contribution description",
  "dataverse_doi": "10.xxxx/xxxxx"
}
```

### 6. Testing Your Dataset

```r
# Test the complete pipeline
source("01_download.R")
source("02_clean.R")
source("03_validate.R")
source("04_export.R")

# Test loading with the package
library(cidadosSP)
data <- get_dataset("your_dataset_name")

# Test citation
cite_dataset("your_dataset_name", format = "bibtex")
```

## 📝 Code Style Guidelines

### R Code Style
- Use tidyverse style guide
- Comment your code extensively
- Use meaningful variable names
- Keep functions small and focused

### File Naming
- Use snake_case for all files
- Be consistent with existing patterns
- Include year in filename when applicable

### Git Commits
- Use clear, descriptive commit messages
- Commit frequently with logical chunks
- Reference issues when applicable

Example:
```
Add IPTU dataset processing pipeline

- Implement download script with retry logic
- Add cleaning for 2020-2024 data
- Include validation for CPF/CNPJ fields
- Closes #15
```

## 🔍 Review Process

1. **Self-Review Checklist**
   - [ ] All scripts run without errors
   - [ ] Documentation is complete
   - [ ] Metadata is accurate
   - [ ] Citations are properly formatted
   - [ ] Data passes validation (>95% quality score)
   - [ ] renv.lock file is included

2. **Submit Pull Request**
   - Push your branch to GitHub
   - Create a pull request with:
     - Description of the dataset
     - Link to source data
     - Any special considerations
     - Screenshots of validation results

3. **Review Timeline**
   - Initial review: 2-3 business days
   - Feedback incorporation: As needed
   - Final approval: 1-2 business days after changes

## 🐛 Reporting Issues

Found a problem with an existing dataset?

1. Check if an issue already exists
2. If not, create a new issue with:
   - Dataset name
   - Description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Your R session info (`sessionInfo()`)

## 💡 Suggesting Improvements

We welcome suggestions! Please open an issue with:
- [Enhancement] tag
- Clear description of the improvement
- Rationale and benefits
- Example implementation (if applicable)

## 📚 Resources

- [Tidyverse Style Guide](https://style.tidyverse.org/)
- [R Packages Book](https://r-pkgs.org/)
- [Dataverse Documentation](https://guides.dataverse.org/)
- [Apache Parquet](https://parquet.apache.org/)

## 🤝 Community Guidelines

- Be respectful and constructive
- Help others when you can
- Share knowledge and learnings
- Acknowledge others' contributions

## 📮 Contact

- **Email**: cidades@insper.edu.br
- **GitHub Issues**: [Create an issue](https://github.com/insper-cidades/cidadosSP/issues)
- **Office Hours**: Tuesdays 14:00-16:00 (by appointment)

## 🙏 Acknowledgments

Thank you to all researchers who have contributed their scripts and expertise to make São Paulo's public data more accessible!

---

*Last updated: 2025-01-10*
