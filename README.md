# Trajectory Analysis Extension

This extension provides components for working with trajectory datasets inside CARTO Workflows. Users of this extension can clean and simplify trajectories, compute derivative metrics (speeds, positions, distances...), detect stops, etc.

The Trajectory Analysis extension is compatible with Workflows powered by BigQuery.

## Components

It includes 10 components:

- **From Points**: Convert a set of points into a trajectory
- **To Points**: Convert a trajectory into a set of points
- **Trajectory Splitter**: Split trajectories into segments based on time or distance
- **Stop Detector**: Identify stops within trajectories
- **Compute Metrics**: Calculate speed, distance, and other trajectory metrics
- **Trajectory Cleaner**: Remove noise and outliers from trajectories
- **Trajectory Simplifier**: Reduce trajectory points while preserving shape
- **Get Values at Timestamp**: Extract trajectory values at specific timestamps
- **Trajectory Intersection**: Find which trajectories intersect a polygon or set of polygons
- **Distance from Trajectory**: Calculate distance between points and trajectories

## Building the extension

To build the extension, follow these steps:

1. Install the required dependencies:
   ```
   pip install -r requirements.txt
   ```

2. Package the extension:
   ```
   python carto_extension.py package
   ```

This will create a packaged version of the extension that can be installed in your CARTO Workflows.

## Running the test

To run the tests follow [these instructions](https://github.com/CartoDB/workflows-extension-template/blob/master/doc/running_tests.md). You would also need to specify the location of the Analytics Toolbox in the `.env` file, for instance:

```
ANALYTICS_TOOLBOX_LOCATION="`carto-un.carto`"
```

**NOTE**: please mind the backticks inside the string value; these are compulsory if the project or dataset contains spaces, hyphens or other non-standard characters allowed by BigQuery for FQNs.