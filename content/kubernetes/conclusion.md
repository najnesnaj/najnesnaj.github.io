---
title: 'Conclusion'
weight: 240
draft: false
---

# Conclusion

This project aimed to develop a containerized, cloud-based application to identify stocks with behavior similar to Deutz using a NoSQL PostgreSQL database with JSONB data. Five distinct approaches were explored to analyze and match time series patterns, including threshold-based filtering, machine learning with Keras, LLM-generated scripts, randomized data variation, PyCaret’s automated model selection, and Dynamic Time Warping (DTW) with the dtaidistance library. Despite these efforts, none of the approaches yielded conclusive results, as each identified too many companies that did not closely resemble Deutz’s stock behavior.The primary challenge was the lack of specificity in the models, likely due to the unlabelled nature of the large time series dataset and the complexity of capturing Deutz’s unique stock behavior mathematically. While tools like PyCaret and dtaidistance offered efficient workflows and robust distance metrics, the results suggest that more refined feature engineering, additional labeled data, or hybrid approaches combining domain-specific criteria with advanced machine learning techniques may be necessary. Future work could focus on incorporating external market indicators, fine-tuning model parameters, or leveraging more sophisticated time series clustering methods to improve pattern recognition accuracy. This project highlights the challenges of time series similarity search in real data and underscores the need for iterative refinement in such applications.

# things learned

The primary objective of this educational project was getting acquinted with the cloud (Azure), techniques like containerisation, kubernetes, and continuous development and integration. It cannot be overstated that learning hands on, yields enormous results in my personal case. Moreover, much of the effort, could not go unwasted in the workplace.
