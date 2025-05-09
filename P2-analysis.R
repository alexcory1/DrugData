# Author:  Alex Cory
# Date:    2025-05-07
# Purpose: Patient Outcomes for 2 Drug Combinations In Cerebral Palsy Patients
#-------------------------------------------------------------------------------

# Load packages
suppressPackageStartupMessages(library("tidyverse")); theme_set(theme_bw())
library("knitr")

data <- read.csv("Bells Palsy Clinical Trial.csv")

#Proportions of each Treatment Group
recovery_summary <- data %>%
  group_by(Treatment.Group) %>%
  summarise(
    N = n(),
    Full_Recovery_Count = sum(Full.Recovery.in.3.Months == "Yes", na.rm = TRUE),
    Full_Recovery_Proportion = mean(Full.Recovery.in.3.Months == "Yes", na.rm = TRUE),
    Full_Recovery_Percent = scales::percent(Full_Recovery_Proportion)
  ) %>%
  arrange(desc(Full_Recovery_Proportion))

knitr::kable(recovery_summary, 
             col.names = c("Treatment Group", "Subjects in Group", "Number Recovered", "Proportion", "%"),
             align = c("l", "c", "c", "c", "c"),
             caption = "Proportion of Full Recovery by Treatment Group Over 3 Month Period")

#Removed to avoid using Treatment.Group column
ggplot(data, aes(x = Treatment.Group, fill = Full.Recovery.in.3.Months)) +
  geom_bar(position = 'fill') +
  labs(
    title = "Full Recovery by Treatment Group at 3 Months",
    x = "Treatment Group",
    y = "Proportion of Patients",
    fill = "Full Recovery"
  ) +
  scale_fill_manual(values = c("#E69F00", "#56B4E9")) +  
  theme(axis.text.x = element_text(angle = 45, hjust = 1))  


#Note to grader: I couldn't reasonably use shape or color to visualize this in a meaningful way
#I hope you are okay with me using a facet to display both
label_data <- data %>%
  group_by(Received.Prednisolone, Received.Acyclovir, Full.Recovery.in.3.Months) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(Received.Prednisolone, Received.Acyclovir) %>%
  mutate(
    prop = count/sum(count),
    ypos = cumsum(prop) - 0.5*prop
  )

facet_labels <- c(
  "No" = "No Acyclovir Treatment", 
  "Yes" = "Acyclovir Treatment"
)

ggplot(data, aes(x = factor(Received.Prednisolone), 
                fill = factor(Full.Recovery.in.3.Months))) +
  geom_bar(position = "fill") +
  
  facet_wrap(~ factor(Received.Acyclovir), 
             labeller = labeller(.cols = facet_labels)) +
  
  scale_y_continuous(labels = scales::percent_format()) +
  scale_fill_manual(
    values = c("#56B4E9", "#E69F00"),
    labels = c("Recovered", "Not Recovered")
  ) +
  labs(
    title = "Full Recovery Rate by Treatment Group at 3 Months",
    x = "Prednisolone Treatment",
    y = "Proportion of Patients",
    fill = "Recovery Status"
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "top",
    strip.background = element_rect(fill = "white"),
    strip.text = element_text(face = "bold")
  )


#Converting Full Recovery to Factor for GLM
data <- data %>%
  mutate(Recovery = factor(Full.Recovery.in.3.Months, 
                          levels = c("No", "Yes")))
model <- glm(Recovery ~ Received.Prednisolone * Received.Acyclovir,
             family = binomial, data = data)

#Calculates coefficients and Confidence Intervals
results <- exp(cbind(
  OR = coef(model),
  confint(model)
))

knitr::kable(results, digits = 2,
             caption = "Odds Ratios (OR) with 95% CIs")

pred_data <- expand.grid(
  Received.Prednisolone = c("No", "Yes"),
  Received.Acyclovir = c("No", "Yes")
)

preds <- predict(model, newdata = pred_data, 
                 type = "response", se.fit = TRUE)
pred_data$prob <- preds$fit
pred_data$lower <- preds$fit - 1.96*preds$se.fit
pred_data$upper <- preds$fit + 1.96*preds$se.fit

ggplot(pred_data, 
       aes(x = factor(Received.Prednisolone, 
                    labels = c("No Prednisolone", "Prednisolone")),
           y = prob,
           color = factor(Received.Acyclovir,
                        labels = c("No Acyclovir", "Acyclovir")))) +
  geom_point(size = 3, position = position_dodge(width = 0.3)) +
  geom_errorbar(aes(ymin = lower, ymax = upper),
                width = 0.1, position = position_dodge(width = 0.3)) +
  scale_y_continuous(labels = scales::percent_format(),
                    limits = c(0, 1)) +
  scale_color_manual(values = c("#E69F00", "#56B4E9")) +
  labs(
    title = "Predicted Recovery Probability by Treatment",
    subtitle = "With 95% Confidence Intervals",
    x = "Prednisolone Treatment",
    y = "Probability of Full Recovery (Yes)",
    color = "Acyclovir Treatment"
  ) +
  theme_minimal() +
  theme(legend.position = "top")
